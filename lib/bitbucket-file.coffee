Shell = require 'shell'
{Range} = require 'atom'
parseUrl = require('url').parse

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
  blame: (lineRange) ->
    if @isOpenable()
      @openUrlInBrowser(@blameUrl() + @getLineRangeSuffix(lineRange))
    else
      @reportValidationErrors()

  history: ->
    if @isOpenable()
      @openUrlInBrowser(@historyUrl())
    else
      @reportValidationErrors()

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
    if @isOpenable()
      @openUrlInBrowser(@issuesUrl())
    else
      @reportValidationErrors()

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
        "#cl-#{startRow}"
      else
        "#cl-#{startRow}:#{endRow}"
    else
      ''

  # Public
  isOpenable: ->
    @validationErrors().length is 0

  # Public
  validationErrors: ->
    unless @repo
      return ["No repository found for path: #{@filePath}."]

    unless @gitUrl()
      return ["No URL defined for remote: #{@remoteName()}"]

    unless @bitbucketRepoUrl()
      return ["Remote URL is not hosted on Bitbucket: #{@gitUrl()}"]

    []

  # Internal
  reportValidationErrors: ->
    message = @validationErrors().join('\n')
    atom.notifications.addWarning(message)

  # Internal
  openUrlInBrowser: (url) ->
    Shell.openExternal url

  # Internal
  blobUrl: ->
    "#{@bitbucketRepoUrl()}/src/#{@encodeSegments(@branchName())}/#{@encodeSegments(@repoRelativePath())}"

  # Internal
  shaUrl: ->
    "#{@bitbucketRepoUrl()}/src/#{@encodeSegments(@sha())}/#{@encodeSegments(@repoRelativePath())}"

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
    "#{@bitbucketRepoUrl()}/branch/#{@encodeSegments(@branchName())}"

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
    if url.match /https:\/\/[^\/]+\// # e.g., https://bitbucket.org/foo/bar.git
      url = url.replace(/\.git$/, '')
    else if url.match /git[^@]*@[^:]+:/    # e.g., git@bitbucket.org:foo/bar.git
      url = url.replace /^git[^@]*@([^:]+):(.+)$/, (match, host, repoPath) ->
        repoPath = repoPath.replace(/^\/+/, '') # replace leading slashes
        "http://#{host}/#{repoPath}".replace(/\.git$/, '')
    else if url.match /ssh:\/\/git@([^\/]+)\//    # e.g., ssh://git@bitbucket.org/foo/bar.git
      url = "http://#{url.substring(10).replace(/\.git$/, '')}"
    else if url.match /^git:\/\/[^\/]+\// # e.g., git://bitbucket.org/foo/bar.git
      url = "http#{url.substring(3).replace(/\.git$/, '')}"

    url = url.replace(/\/+$/, '')

    return url unless @isGithubUrl(url)

  isGithubUrl: (url) ->
    return true if url.indexOf('git@github.com') is 0

    try
      {host} = parseUrl(url)
      host is 'github.com'

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
    @repo.getReferenceTarget("HEAD", @filePath)

  # Internal
  branchName: ->
    shortBranch = @repo.getShortHead(@filePath)
    return null unless shortBranch

    branchMerge = @repo.getConfigValue("branch.#{shortBranch}.merge", @filePath)
    return shortBranch unless branchMerge?.length > 11
    return shortBranch unless branchMerge.indexOf('refs/heads/') is 0

    branchMerge.substring(11)
