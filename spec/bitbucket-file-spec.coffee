BitbucketFile = require '../lib/bitbucket-file'
fs = require 'fs-plus'
path = require 'path'
os = require 'os'

describe "BitbucketFile", ->
  [bitbucketFile, editor] = []

  describe "commands", ->
    workingDirPath = path.join(os.tmpdir(), 'open-on-bitbucket-working-dir')
    filePathRelativeToWorkingDir = 'some-dir/some-file.md'

    fixturePath = (fixtureName) ->
      path.join(__dirname, "fixtures", "#{fixtureName}.git")

    setupWorkingDir = (fixtureName) ->
      fs.makeTreeSync workingDirPath
      fs.copySync fixturePath(fixtureName), path.join(workingDirPath, '.git')

      subdirectoryPath = path.join(workingDirPath, 'some-dir')
      fs.makeTreeSync subdirectoryPath

      filePath = path.join(subdirectoryPath, 'some-file.md')
      fs.writeFileSync filePath, 'some file content'

    setupBitbucketFile = ->
      atom.project.setPaths([workingDirPath])
      waitsForPromise ->
        atom.workspace.open(filePathRelativeToWorkingDir)

      runs ->
        editor = atom.workspace.getActiveTextEditor()
        bitbucketFile = BitbucketFile.fromPath(editor.getPath())

    teardownWorkingDirAndRestoreFixture = (fixtureName) ->
      success = null

      # On Windows, you can not remove a watched directory/file, therefore we
      # have to close the project before attempting to delete. Unfortunately,
      # Pathwatcher's close function is also not synchronous. Once
      # atom/node-pathwatcher#4 is implemented this should be alot cleaner.
      runs ->
        atom.project.setPaths([])
        repeat = setInterval ->
          try
            fs.removeSync(workingDirPath)
            clearInterval(repeat)
            success = true
          catch e
            success = false
        , 50

      waitsFor -> success

    describe "open", ->
      describe "when the file is openable on Bitbucket.org", ->
        fixtureName = 'bitbucket-remote'

        beforeEach ->
          setupWorkingDir(fixtureName)
          setupBitbucketFile()

        afterEach ->
          teardownWorkingDirAndRestoreFixture(fixtureName)

        it "opens the Bitbucket.org src URL for the file", ->
          spyOn(bitbucketFile, 'openUrlInBrowser')
          bitbucketFile.open()
          expect(bitbucketFile.openUrlInBrowser).toHaveBeenCalledWith \
            'https://bitbucket.org/some-user/some-repo/src/master/some-dir/some-file.md'

        describe "when text is selected", ->
          it "opens the Bitbucket.org src URL for the file with the selection range in the hash", ->
            atom.config.set('open-on-bitbucket.includeLineNumbersInUrls', true)
            spyOn(bitbucketFile, 'openUrlInBrowser')
            bitbucketFile.open([[0, 0], [1, 1]])
            expect(bitbucketFile.openUrlInBrowser).toHaveBeenCalledWith \
              'https://bitbucket.org/some-user/some-repo/src/master/some-dir/some-file.md#cl-1:2'

        describe "when the file has a '#' in its name", ->
          it "opens the Bitbucket.org src URL for the file", ->
            waitsForPromise ->
              atom.workspace.open('a/b#/test#hash.md')

            runs ->
              editor = atom.workspace.getActiveTextEditor()
              bitbucketFile = BitbucketFile.fromPath(editor.getPath())
              spyOn(bitbucketFile, 'openUrlInBrowser')
              bitbucketFile.open()
              expect(bitbucketFile.openUrlInBrowser).toHaveBeenCalledWith \
                'https://bitbucket.org/some-user/some-repo/src/master/a/b%23/test%23hash.md'

      describe "when the branch has a '/' in its name", ->
        fixtureName = 'branch-with-slash-in-name'

        beforeEach ->
          setupWorkingDir(fixtureName)
          setupBitbucketFile()

        afterEach ->
          teardownWorkingDirAndRestoreFixture(fixtureName)

        it "opens the Bitbucket.org src URL for the file", ->
          spyOn(bitbucketFile, 'openUrlInBrowser')
          bitbucketFile.open()
          expect(bitbucketFile.openUrlInBrowser).toHaveBeenCalledWith \
            'https://bitbucket.org/some-user/some-repo/src/foo/bar/some-dir/some-file.md'

      describe "when the branch has a '#' in its name", ->
        fixtureName = 'branch-with-hash-in-name'

        beforeEach ->
          setupWorkingDir(fixtureName)
          setupBitbucketFile()

        afterEach ->
          teardownWorkingDirAndRestoreFixture(fixtureName)

        it "opens the Bitbucket.org src URL for the file", ->
          spyOn(bitbucketFile, 'openUrlInBrowser')
          bitbucketFile.open()
          expect(bitbucketFile.openUrlInBrowser).toHaveBeenCalledWith \
            'https://bitbucket.org/some-user/some-repo/src/a%23b%23c/some-dir/some-file.md'

      describe "when the remote has a '/' in its name", ->
        fixtureName = 'remote-with-slash-in-name'

        beforeEach ->
          setupWorkingDir(fixtureName)
          setupBitbucketFile()

        afterEach ->
          teardownWorkingDirAndRestoreFixture(fixtureName)

        it "opens the Bitbucket.org src URL for the file", ->
          spyOn(bitbucketFile, 'openUrlInBrowser')
          bitbucketFile.open()
          expect(bitbucketFile.openUrlInBrowser).toHaveBeenCalledWith \
            'https://bitbucket.org/some-user/some-repo/src/baz/some-dir/some-file.md'

      describe "when the local branch is not tracked", ->
        fixtureName = 'non-tracked-branch'

        beforeEach ->
          setupWorkingDir(fixtureName)
          setupBitbucketFile()

        afterEach ->
          teardownWorkingDirAndRestoreFixture(fixtureName)

        it "opens the Bitbucket.org src URL for the file on the master branch", ->
          spyOn(bitbucketFile, 'openUrlInBrowser')
          bitbucketFile.open()
          expect(bitbucketFile.openUrlInBrowser).toHaveBeenCalledWith \
            'https://bitbucket.org/some-user/some-repo/src/master/some-dir/some-file.md'

      describe "when there is no remote", ->
        fixtureName = 'no-remote'

        beforeEach ->
          setupWorkingDir(fixtureName)
          setupBitbucketFile()

        afterEach ->
          teardownWorkingDirAndRestoreFixture(fixtureName)

        it "logs an error", ->
          spyOn(atom.notifications, 'addWarning')
          bitbucketFile.open()
          expect(atom.notifications.addWarning).toHaveBeenCalledWith \
            'No URL defined for remote: null'

      describe "when the root directory doesn't have a git repo", ->
        beforeEach ->
          teardownWorkingDirAndRestoreFixture()
          fs.mkdirSync(workingDirPath)
          setupBitbucketFile()

        it "does nothing", ->
          spyOn(atom.notifications, 'addWarning')
          bitbucketFile.open()
          expect(atom.notifications.addWarning).toHaveBeenCalled()
          expect(atom.notifications.addWarning.mostRecentCall.args[0]).toContain("No repository found")

      describe "when the remote repo is not hosted on bitbucket.org", ->
        fixtureName = 'bitbucket-enterprise-remote'

        beforeEach ->
          setupWorkingDir(fixtureName)
          bitbucketFile = setupBitbucketFile()

        afterEach ->
          teardownWorkingDirAndRestoreFixture(fixtureName)

        it "opens a Bitbucket Server src URL for the file", ->
          spyOn(bitbucketFile, 'openUrlInBrowser')
          bitbucketFile.open()
          expect(bitbucketFile.openUrlInBrowser).toHaveBeenCalledWith \
            'https://git.enterprize.me/projects/some-project/repos/some-repo/browse/some-dir/some-file.md?at=master'

    describe "openOnMaster", ->
      fixtureName = 'non-tracked-branch'

      beforeEach ->
        setupWorkingDir(fixtureName)
        setupBitbucketFile()

      afterEach ->
        teardownWorkingDirAndRestoreFixture(fixtureName)

      it "opens the Bitbucket.org src URL for the file", ->
        spyOn(bitbucketFile, 'openUrlInBrowser')
        bitbucketFile.openOnMaster()
        expect(bitbucketFile.openUrlInBrowser).toHaveBeenCalledWith \
          'https://bitbucket.org/some-user/some-repo/src/master/some-dir/some-file.md'

    describe "blame", ->
      describe "when the file is openable on Bitbucket.org", ->
        fixtureName = 'bitbucket-remote'

        beforeEach ->
          setupWorkingDir(fixtureName)
          setupBitbucketFile()

        afterEach ->
          teardownWorkingDirAndRestoreFixture(fixtureName)

        it "opens the Bitbucket.org blame URL for the file", ->
          spyOn(bitbucketFile, 'openUrlInBrowser')
          bitbucketFile.blame()
          expect(bitbucketFile.openUrlInBrowser).toHaveBeenCalledWith \
            'https://bitbucket.org/some-user/some-repo/annotate/master/some-dir/some-file.md'

        describe "when text is selected", ->
          it "opens the Bitbucket.org blame URL for the file with the selection range in the hash", ->
            atom.config.set('open-on-bitbucket.includeLineNumbersInUrls', true)
            spyOn(bitbucketFile, 'openUrlInBrowser')
            bitbucketFile.blame([[0, 0], [1, 1]])
            expect(bitbucketFile.openUrlInBrowser).toHaveBeenCalledWith \
              'https://bitbucket.org/some-user/some-repo/annotate/master/some-dir/some-file.md#cl-1:2'

      describe "when the remote repo is not hosted on bitbucket.org", ->
        fixtureName = 'bitbucket-enterprise-remote'

        beforeEach ->
          setupWorkingDir(fixtureName)
          setupBitbucketFile()

        afterEach ->
          teardownWorkingDirAndRestoreFixture(fixtureName)

        it "logs an error", ->
          spyOn(atom.notifications, 'addWarning')
          bitbucketFile.blame()
          expect(atom.notifications.addWarning).toHaveBeenCalledWith \
            'This feature is only available when hosting repositories on Bitbucket (bitbucket.org)'

    describe "branchCompare", ->
      describe "when the file is openable on Bitbucket.org", ->
        fixtureName = 'bitbucket-remote'

        beforeEach ->
          setupWorkingDir(fixtureName)
          setupBitbucketFile()

        afterEach ->
          teardownWorkingDirAndRestoreFixture(fixtureName)

        it "opens the Bitbucket.org branch compare URL for the file", ->
          spyOn(bitbucketFile, 'openUrlInBrowser')
          bitbucketFile.openBranchCompare()
          expect(bitbucketFile.openUrlInBrowser).toHaveBeenCalledWith \
            'https://bitbucket.org/some-user/some-repo/branch/master'

      describe "when the remote repo is not hosted on bitbucket.org", ->
        fixtureName = 'bitbucket-enterprise-remote'

        beforeEach ->
          setupWorkingDir(fixtureName)
          bitbucketFile = setupBitbucketFile()

        afterEach ->
          teardownWorkingDirAndRestoreFixture(fixtureName)

        it "opens a Bitbucket Server src URL for the file", ->
          spyOn(bitbucketFile, 'openUrlInBrowser')
          bitbucketFile.openBranchCompare()
          expect(bitbucketFile.openUrlInBrowser).toHaveBeenCalledWith \
            'https://git.enterprize.me/projects/some-project/repos/some-repo/compare/commits?sourceBranch=master'

    describe "history", ->
      describe "when the file is openable on Bitbucket.org", ->
        fixtureName = 'bitbucket-remote'

        beforeEach ->
          setupWorkingDir(fixtureName)
          setupBitbucketFile()

        afterEach ->
          teardownWorkingDirAndRestoreFixture(fixtureName)

        it "opens the Bitbucket.org history URL for the file", ->
          spyOn(bitbucketFile, 'openUrlInBrowser')
          bitbucketFile.history()
          expect(bitbucketFile.openUrlInBrowser).toHaveBeenCalledWith \
            'https://bitbucket.org/some-user/some-repo/history-node/master/some-dir/some-file.md'

      describe "when the remote repo is not hosted on bitbucket.org", ->
        fixtureName = 'bitbucket-enterprise-remote'

        beforeEach ->
          setupWorkingDir(fixtureName)
          setupBitbucketFile()

        afterEach ->
          teardownWorkingDirAndRestoreFixture(fixtureName)

        it "logs an error", ->
          spyOn(atom.notifications, 'addWarning')
          bitbucketFile.history()
          expect(atom.notifications.addWarning).toHaveBeenCalledWith \
            'This feature is only available when hosting repositories on Bitbucket (bitbucket.org)'

    describe "copyUrl", ->
      describe "when the file is openable on Bitbucket.org", ->
        fixtureName = 'bitbucket-remote'

        beforeEach ->
          setupWorkingDir(fixtureName)
          atom.config.set('open-on-bitbucket.includeLineNumbersInUrls', true)
          setupBitbucketFile()

        afterEach ->
          teardownWorkingDirAndRestoreFixture(fixtureName)

        describe "when text is selected", ->
          it "copies the URL to the clipboard with the selection range in the hash", ->
            bitbucketFile.copyUrl([[0, 0], [1, 1]])
            expect(atom.clipboard.read()).toBe 'https://bitbucket.org/some-user/some-repo/src/80b7897ceb6bd7531708509b50afeab36a4b73fd/some-dir/some-file.md#cl-1:2'

        describe "when no text is selected", ->
          it "copies the URL to the clipboard with the cursor location in the hash", ->
            bitbucketFile.copyUrl([[2, 1], [2, 1]])
            expect(atom.clipboard.read()).toBe 'https://bitbucket.org/some-user/some-repo/src/80b7897ceb6bd7531708509b50afeab36a4b73fd/some-dir/some-file.md#cl-3'

      describe "when the remote repo is not hosted on bitbucket.org", ->
        fixtureName = 'bitbucket-enterprise-remote'

        beforeEach ->
          setupWorkingDir(fixtureName)
          atom.config.set('open-on-bitbucket.includeLineNumbersInUrls', true)
          setupBitbucketFile()

        afterEach ->
          teardownWorkingDirAndRestoreFixture(fixtureName)

        describe "when text is selected", ->
          it "copies the URL to the clipboard with the selection range in the hash", ->
            bitbucketFile.copyUrl([[0, 0], [1, 1]])
            expect(atom.clipboard.read()).toBe 'https://git.enterprize.me/projects/some-project/repos/some-repo/browse/some-dir/some-file.md?at=80b7897ceb6bd7531708509b50afeab36a4b73fd#1-2'

        describe "when no text is selected", ->
          it "copies the URL to the clipboard with the cursor location in the hash", ->
            bitbucketFile.copyUrl([[2, 1], [2, 1]])
            expect(atom.clipboard.read()).toBe 'https://git.enterprize.me/projects/some-project/repos/some-repo/browse/some-dir/some-file.md?at=80b7897ceb6bd7531708509b50afeab36a4b73fd#3'

    describe "openRepository", ->
      describe "when the file is openable on Bitbucket.org", ->
        fixtureName = 'bitbucket-remote'

        beforeEach ->
          setupWorkingDir(fixtureName)
          setupBitbucketFile()

        afterEach ->
          teardownWorkingDirAndRestoreFixture(fixtureName)

        it "opens the Bitbucket.org repository URL", ->
          spyOn(bitbucketFile, 'openUrlInBrowser')
          bitbucketFile.openRepository()
          expect(bitbucketFile.openUrlInBrowser).toHaveBeenCalledWith \
            'https://bitbucket.org/some-user/some-repo'

      describe "when the remote repo is not hosted on bitbucket.org", ->
        fixtureName = 'bitbucket-enterprise-remote'

        beforeEach ->
          setupWorkingDir(fixtureName)
          setupBitbucketFile()

        afterEach ->
          teardownWorkingDirAndRestoreFixture(fixtureName)

        it "opens a Bitbucket Server repository URL for the file", ->
          spyOn(bitbucketFile, 'openUrlInBrowser')
          bitbucketFile.openRepository()
          expect(bitbucketFile.openUrlInBrowser).toHaveBeenCalledWith \
            'https://git.enterprize.me/projects/some-project/repos/some-repo'


    describe "openIssues", ->
      describe 'when the file is openable on Bitbucket.org', ->
        fixtureName = 'bitbucket-remote'

        beforeEach ->
          setupWorkingDir(fixtureName)
          setupBitbucketFile()

        afterEach ->
          teardownWorkingDirAndRestoreFixture(fixtureName)

        it 'opens the Bitbucket.org issues URL', ->
          spyOn(bitbucketFile, 'openUrlInBrowser')
          bitbucketFile.openIssues()
          expect(bitbucketFile.openUrlInBrowser).toHaveBeenCalledWith \
            'https://bitbucket.org/some-user/some-repo/issues'

      describe "when the remote repo is not hosted on bitbucket.org", ->
        fixtureName = 'bitbucket-enterprise-remote'

        beforeEach ->
          setupWorkingDir(fixtureName)
          setupBitbucketFile()

        afterEach ->
          teardownWorkingDirAndRestoreFixture(fixtureName)

        it "logs an error", ->
          spyOn(atom.notifications, 'addWarning')
          bitbucketFile.openIssues()
          expect(atom.notifications.addWarning).toHaveBeenCalledWith \
            'This feature is only available when hosting repositories on Bitbucket (bitbucket.org)'

  describe "bitbucketRepoUrl", ->
    beforeEach ->
      bitbucketFile = new BitbucketFile()

    it "returns the Bitbucket.org URL for an HTTP remote URL", ->
      bitbucketFile.gitUrl = -> "https://bitbucket.org/foo/bar.git"
      expect(bitbucketFile.bitbucketRepoUrl()).toBe "https://bitbucket.org/foo/bar"

    it "returns the Bitbucket url for an HTTP non SSL remote URL", ->
      bitbucketFile.gitUrl = -> "http://bitbucket.org/foo/bar.git"
      expect(bitbucketFile.bitbucketRepoUrl()).toBe "http://bitbucket.org/foo/bar"

    it "returns the Bitbucket.org URL for an SSH remote URL", ->
      bitbucketFile.gitUrl = -> "git@bitbucket.org:foo/bar.git"
      expect(bitbucketFile.bitbucketRepoUrl()).toBe "http://bitbucket.org/foo/bar"

    it "returns a Bitbucket Server URL for an SSH remote URL with a non-standard user", ->
      bitbucketFile.gitUrl = -> "git-user@git.enterprize.me:foo/bar.git"
      expect(bitbucketFile.bitbucketRepoUrl()).toBe "http://git.enterprize.me/projects/foo/repos/bar"

    it "returns a Bitbucket Server URL for an SSH remote URL with a non-standard port", ->
      bitbucketFile.gitUrl = -> "ssh://git@git.enterprize.me:1234/foo/bar.git"
      expect(bitbucketFile.bitbucketRepoUrl()).toBe "http://git.enterprize.me/projects/foo/repos/bar"

    it "returns a Bitbucket Server URL for a non-Github.com remote URL", ->
      bitbucketFile.gitUrl = -> "https://user@git.enterprize.me/scm/foo/bar.git"
      expect(bitbucketFile.bitbucketRepoUrl()).toBe "https://git.enterprize.me/projects/foo/repos/bar"

      bitbucketFile.gitUrl = -> "git@git.enterprize.me:foo/bar.git"
      expect(bitbucketFile.bitbucketRepoUrl()).toBe "http://git.enterprize.me/projects/foo/repos/bar"

    it "returns the Bitbucket.org URL for a git:// URL", ->
      bitbucketFile.gitUrl = -> "git://bitbucket.org/foo/bar.git"
      expect(bitbucketFile.bitbucketRepoUrl()).toBe "http://bitbucket.org/foo/bar"

    it "returns the Bitbucket.org URL for a ssh:// URL", ->
      bitbucketFile.gitUrl = -> "ssh://git@bitbucket.org/foo/bar.git"
      expect(bitbucketFile.bitbucketRepoUrl()).toBe "http://bitbucket.org/foo/bar"

    it "returns undefined for GithubURLs", ->
      bitbucketFile.gitUrl = -> "https://github.com/somebody/repo.git"
      expect(bitbucketFile.bitbucketRepoUrl()).toBeUndefined()

      bitbucketFile.gitUrl = -> "https://github.com/somebody/repo"
      expect(bitbucketFile.bitbucketRepoUrl()).toBeUndefined()

      bitbucketFile.gitUrl = -> "git@github.com:somebody/repo.git"
      expect(bitbucketFile.bitbucketRepoUrl()).toBeUndefined()

      bitbucketFile.gitUrl = -> "git@github.com:somebody/repo"
      expect(bitbucketFile.bitbucketRepoUrl()).toBeUndefined()

    it "removes leading and trailing slashes", ->
      bitbucketFile.gitUrl = -> "https://bitbucket.org/foo/bar/"
      expect(bitbucketFile.bitbucketRepoUrl()).toBe "https://bitbucket.org/foo/bar"

      bitbucketFile.gitUrl = -> "https://bitbucket.org/foo/bar//////"
      expect(bitbucketFile.bitbucketRepoUrl()).toBe "https://bitbucket.org/foo/bar"

      bitbucketFile.gitUrl = -> "git@bitbucket.org:/foo/bar.git"
      expect(bitbucketFile.bitbucketRepoUrl()).toBe "http://bitbucket.org/foo/bar"

  it "activates when a command is triggered on the active editor", ->
    activationPromise = atom.packages.activatePackage('open-on-bitbucket')

    waitsForPromise ->
      atom.workspace.open()

    runs ->
      atom.commands.dispatch(atom.views.getView(atom.workspace.getActivePane()), 'open-on-bitbucket:file')

    waitsForPromise ->
      activationPromise
