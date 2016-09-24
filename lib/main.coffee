BitbucketFile = require './bitbucket-file'

plugin = module.exports

plugin.config =
  includeLineNumbersInUrls:
    default: true
    type: 'boolean'
    description: 'Include the line range selected in the editor when opening or copying URLs to the clipboard. When opened in the browser, the Bitbucket page will automatically scroll to the selected line range.'

plugin.activate = ->
  atom.commands.add ".tree-view .file .name, atom-pane", "open-on-bitbucket:blame", openBitbucketBlame
  atom.commands.add ".tree-view .file .name, atom-pane", "open-on-bitbucket:branch-compare", openBitbucketBranchCompare
  atom.commands.add ".tree-view .file .name, atom-pane", "open-on-bitbucket:copy-url", openBitbucketCopyUrl
  atom.commands.add ".tree-view .file .name, atom-pane", "open-on-bitbucket:file", openBitbucketFile
  atom.commands.add ".tree-view .file .name, atom-pane", "open-on-bitbucket:file-on-master", openBitbucketFileOnMaster
  atom.commands.add ".tree-view .file .name, atom-pane", "open-on-bitbucket:history", openBitbucketHistory
  atom.commands.add ".tree-view .file .name, atom-pane", "open-on-bitbucket:issues", openBitbucketIssues
  atom.commands.add ".tree-view .file .name, atom-pane", "open-on-bitbucket:repository", openBitbucketRepository

openBitbucketBlame = ({target}) ->
  itemPath = if target.dataset.path then target.dataset.path else getActivePath()
  selectedRange = if target.dataset.path then [[0, 0], [0, 0]] else getSelectedRange()
  BitbucketFile.fromPath(itemPath).blame(selectedRange)

openBitbucketBranchCompare = ({target}) ->
  itemPath = if target.dataset.path then target.dataset.path else getActivePath()
  selectedRange = if target.dataset.path then [[0, 0], [0, 0]] else getSelectedRange()
  BitbucketFile.fromPath(itemPath).openBranchCompare()

openBitbucketCopyUrl = ({target}) ->
  itemPath = if target.dataset.path then target.dataset.path else getActivePath()
  selectedRange = if target.dataset.path then [[0, 0], [0, 0]] else getSelectedRange()
  BitbucketFile.fromPath(itemPath).copyUrl(selectedRange)

openBitbucketFile = ({target}) ->
  itemPath = if target.dataset.path then target.dataset.path else getActivePath()
  selectedRange = if target.dataset.path then [[0, 0], [0, 0]] else getSelectedRange()
  BitbucketFile.fromPath(itemPath).open(selectedRange)

openBitbucketFileOnMaster = ({target}) ->
  itemPath = if target.dataset.path then target.dataset.path else getActivePath()
  selectedRange = if target.dataset.path then [[0, 0], [0, 0]] else getSelectedRange()
  BitbucketFile.fromPath(itemPath).openOnMaster(selectedRange)

openBitbucketHistory = ({target}) ->
  itemPath = if target.dataset.path then target.dataset.path else getActivePath()
  selectedRange = if target.dataset.path then [[0, 0], [0, 0]] else getSelectedRange()
  BitbucketFile.fromPath(itemPath).history()

openBitbucketIssues = ({target}) ->
  itemPath = if target.dataset.path then target.dataset.path else getActivePath()
  selectedRange = if target.dataset.path then [[0, 0], [0, 0]] else getSelectedRange()
  BitbucketFile.fromPath(itemPath).openIssues()

openBitbucketRepository = ({target}) ->
  itemPath = if target.dataset.path then target.dataset.path else getActivePath()
  selectedRange = if target.dataset.path then [[0, 0], [0, 0]] else getSelectedRange()
  BitbucketFile.fromPath(itemPath).openRepository()

getActivePath = ->
  atom.workspace.getActivePaneItem()?.getPath?()

getSelectedRange = ->
  atom.workspace.getActivePaneItem()?.getSelectedBufferRange?()
