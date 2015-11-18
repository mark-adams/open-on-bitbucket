Shell = require 'shell'
{Range} = require 'atom'
parseUrl = require('url').parse
formatUrl = require('url').format

module.exports =
class BitbucketFile

  # Public
  @fromPath: (filePath) ->
    new BitbucketFile(filePath)

  # Internal
  constructor: (@filePath) ->
    [rootDir] = atom.project.relativizePath(filePath)
    if rootDir?
      rootDirIndex = atom.project.getPaths().indexOf(rootDir)
      @repo = atom.project.getRepositories()[rootDirIndex]

  # Public
  open: (lineRange) ->
    if @isOpenable()
      @openUrlInBrowser(@blobUrl() + @getLineRangeSuffix(lineRange))
    else
      @reportValidationErrors()

  # Public
  openOnMaster: (lineRange) ->
    if @isOpenable()
      @openUrlInBrowser(@blobUrlForMaster() + @getLineRangeSuffix(lineRange))
    else
      @reportValidationErrors()

  # Public
  blame: (lineRange) ->
    if @isOpenable(true)
      @openUrlInBrowser(@blameUrl() + @getLineRangeSuffix(lineRange))
    else
      @reportValidationErrors(true)

  history: ->
    if @isOpenable(true)
      @openUrlInBrowser(@historyUrl())
    else
      @reportValidationErrors(true)

  copyUrl: (lineRange) ->
    if @isOpenable()
      atom.clipboard.write(@shaUrl() + @getLineRangeSuffix(lineRange))
    else
      @reportValidationErrors()

  openBranchCompare: ->
    if @isOpenable()
      @openUrlInBrowser(@branchCompareUrl())
    else
      @reportValidationErrors()

  openIssues: ->
    if @isOpenable(true)
      @openUrlInBrowser(@issuesUrl())
    else
      @reportValidationErrors(true)

  openRepository: ->
    if @isOpenable()
      @openUrlInBrowser(@bitbucketRepoUrl())
    else
      @reportValidationErrors()

  getLineRangeSuffix: (lineRange) ->
    if lineRange and atom.config.get('open-on-bitbucket.includeLineNumbersInUrls')
      lineRange = Range.fromObject(lineRange)
      startRow = lineRange.start.row + 1
      endRow = lineRange.end.row + 1

      if startRow is endRow
        if @isBitbucketCloudUrl(@gitUrl()) then "#cl-#{startRow}" else "##{startRow}"
      else
        if @isBitbucketCloudUrl(@gitUrl()) then "#cl-#{startRow}:#{endRow}" else "##{startRow}-#{endRow}"
    else
      ''

  # Public
  isOpenable: (disallowStash = false) ->
    @validationErrors(disallowStash).length is 0

  # Public
  validationErrors: (disallowStash) ->
    unless @repo
      return ["No repository found for path: #{@filePath}."]

    unless @gitUrl()
      return ["No URL defined for remote: #{@remoteName()}"]

    unless @bitbucketRepoUrl()
      return ["Remote URL is not hosted on Bitbucket: #{@gitUrl()}"]

    if (disallowStash and @isStashUrl(@gitUrl()))
      return ["This feature is only available when hosting repositories on Bitbucket (bitbucket.org)"]

    []

  # Internal
  reportValidationErrors: (disallowStash = false) ->
    message = @validationErrors(disallowStash).join('\n')
    atom.notifications.addWarning(message)

  # Internal
  openUrlInBrowser: (url) ->
    Shell.openExternal url

  # Internal
  blobUrl: ->
    baseUrl = @bitbucketRepoUrl()

    if @isBitbucketCloudUrl(baseUrl)
      "#{baseUrl}/src/#{@remoteBranchName()}/#{@encodeSegments(@repoRelativePath())}"
    else
      "#{baseUrl}/browse/#{@encodeSegments(@repoRelativePath())}?at=#{@remoteBranchName()}"

  # Internal
  blobUrlForMaster: ->
    baseUrl = @bitbucketRepoUrl()

    if @isBitbucketCloudUrl(baseUrl)
      "#{baseUrl}/src/master/#{@encodeSegments(@repoRelativePath())}"
    else
      "#{baseUrl}/browse/#{@encodeSegments(@repoRelativePath())}?at=master"


  # Internal
  shaUrl: ->
    baseUrl = @bitbucketRepoUrl()

    if @isBitbucketCloudUrl(baseUrl)
      "#{baseUrl}/src/#{@encodeSegments(@sha())}/#{@encodeSegments(@repoRelativePath())}"
    else
      "#{baseUrl}/browse/#{@encodeSegments(@repoRelativePath())}?at=#{@encodeSegments(@sha())}"

  # Internal
  blameUrl: ->
    "#{@bitbucketRepoUrl()}/annotate/#{@encodeSegments(@branchName())}/#{@encodeSegments(@repoRelativePath())}"

  # Internal
  historyUrl: ->
    "#{@bitbucketRepoUrl()}/history-node/#{@encodeSegments(@branchName())}/#{@encodeSegments(@repoRelativePath())}"

  # Internal
  issuesUrl: ->
    "#{@bitbucketRepoUrl()}/issues"

  # Internal
  branchCompareUrl: ->
    baseUrl = @bitbucketRepoUrl()

    if @isBitbucketCloudUrl(baseUrl)
      "#{baseUrl}/branch/#{@encodeSegments(@branchName())}"
    else
      "#{baseUrl}/compare/commits?sourceBranch=#{@encodeSegments(@branchName())}"

  encodeSegments: (segments='') ->
    segments = segments.split('/')
    segments = segments.map (segment) -> encodeURIComponent(segment)
    segments.join('/')

  # Internal
  gitUrl: ->
    remoteOrBestGuess = @remoteName() ? 'origin'
    @repo.getConfigValue("remote.#{remoteOrBestGuess}.url", @filePath)

  # Internal
  bitbucketRepoUrl: ->
    url = @gitUrl()

    if @isGithubUrl(url)
      return
    else if @isBitbucketCloudUrl(url)
      return @bitbucketCloudRepoUrl(url)
    else
      return @stashRepoUrlRepoUrl(url)

  # Internal
  bitbucketCloudRepoUrl: (url) ->
    if url.match /https?:\/\/[^\/]+\// # e.g., https://bitbucket.org/foo/bar.git or http://bitbucket.org/foo/bar.git
      url = url.replace(/\.git$/, '')
    else if url.match /^git[^@]*@[^:]+:/    # e.g., git@bitbucket.org:foo/bar.git
      url = url.replace /^git[^@]*@([^:]+):(.+)$/, (match, host, repoPath) ->
        repoPath = repoPath.replace(/^\/+/, '') # replace leading slashes
        "http://#{host}/#{repoPath}".replace(/\.git$/, '')
    else if url.match /ssh:\/\/git@([^\/]+)\//    # e.g., ssh://git@bitbucket.org/foo/bar.git
      url = "http://#{url.substring(10).replace(/\.git$/, '')}"
    else if url.match /^git:\/\/[^\/]+\// # e.g., git://bitbucket.org/foo/bar.git
      url = "http#{url.substring(3).replace(/\.git$/, '')}"

    url = url.replace(/\.git$/, '')
    url = url.replace(/\/+$/, '')

    return url

  # Internal
  stashRepoUrlRepoUrl: (url) ->
    urlObj = parseUrl(@bitbucketCloudRepoUrl(url))

    urlObj.host = urlObj.hostname
    urlObj.auth = null

    [match, proj, repo] = urlObj.pathname.match /(?:\/scm)?\/(.+)\/(.+)/
    urlObj.pathname = "/projects/#{proj}/repos/#{repo}"

    return formatUrl(urlObj)

  # Internal
  isGithubUrl: (url) ->
    return true if url.indexOf('git@github.com') is 0

    try
      {host} = parseUrl(url)
      host is 'github.com'

  # Internal
  isBitbucketCloudUrl: (url) ->
    return true if url.indexOf('git@bitbucket.org') is 0

    try
      {host} = parseUrl(url)
      host is 'bitbucket.org'

  # Internal
  isStashUrl: (url) ->
    return not (@isGithubUrl(url) or @isBitbucketCloudUrl(url))

  # Internal
  repoRelativePath: ->
    @repo.getRepo(@filePath).relativize(@filePath)

  # Internal
  remoteName: ->
    shortBranch = @repo.getShortHead(@filePath)
    return null unless shortBranch

    branchRemote = @repo.getConfigValue("branch.#{shortBranch}.remote", @filePath)
    return null unless branchRemote?.length > 0

    branchRemote

  # Internal
  sha: ->
    @repo.getReferenceTarget('HEAD', @filePath)

  # Internal
  branchName: ->
    shortBranch = @repo.getShortHead(@filePath)
    return null unless shortBranch

    branchMerge = @repo.getConfigValue("branch.#{shortBranch}.merge", @filePath)
    return shortBranch unless branchMerge?.length > 11
    return shortBranch unless branchMerge.indexOf('refs/heads/') is 0

    branchMerge.substring(11)

  # Internal
  remoteBranchName: ->
    if @remoteName()?
      @encodeSegments(@branchName())
    else
      'master'
