BitbucketFile  = require './bitbucket-file'

module.exports =
  config:
    includeLineNumbersInUrls:
      default: true
      type: 'boolean'
      description: 'Include the line range selected in the editor when opening or copying URLs to the clipboard. When opened in the browser, the GitHub page will automatically scroll to the selected line range.'

  activate: ->
    atom.commands.add 'atom-pane',
      'open-on-bitbucket:file': ->
        if itemPath = getActivePath()
          BitbucketFile.fromPath(itemPath).open(getSelectedRange())

      'open-on-bitbucket:file-on-master': ->
        if itemPath = getActivePath()
          BitbucketFile.fromPath(itemPath).openOnMaster(getSelectedRange())

      'open-on-bitbucket:blame': ->
        if itemPath = getActivePath()
          BitbucketFile.fromPath(itemPath).blame(getSelectedRange())

      'open-on-bitbucket:history': ->
        if itemPath = getActivePath()
          BitbucketFile.fromPath(itemPath).history()

      'open-on-bitbucket:issues': ->
        if itemPath = getActivePath()
          BitbucketFile.fromPath(itemPath).openIssues()

      'open-on-bitbucket:copy-url': ->
        if itemPath = getActivePath()
          BitbucketFile.fromPath(itemPath).copyUrl(getSelectedRange())

      'open-on-bitbucket:branch-compare': ->
        if itemPath = getActivePath()
          BitbucketFile.fromPath(itemPath).openBranchCompare()

      'open-on-bitbucket:repository': ->
        if itemPath = getActivePath()
          BitbucketFile.fromPath(itemPath).openRepository()

getActivePath = ->
  atom.workspace.getActivePaneItem()?.getPath?()

getSelectedRange = ->
  atom.workspace.getActivePaneItem()?.getSelectedBufferRange?()
