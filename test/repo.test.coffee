should   = require 'should'
sinon    = require 'sinon'

fs       = require 'fs-extra'
fixtures = require './fixtures'
git      = require '../src'
Actor    = require '../src/actor'
Commit   = require '../src/commit'
Tree     = require '../src/tree'
Diff     = require '../src/diff'
Tag      = require '../src/tag'
Status   = require '../src/status'

{Ref, Head} = require '../src/ref'
exec        = require 'flex-exec'

describe "Repo", ->

  describe "#add", ->
    repo    = null
    git_dir = __dirname + "/fixtures/junk _$add"
    status  = null
    file    = null

    # given a fresh new repo
    before (done) ->
      fs.remove git_dir, (err) ->
        return done err if err
        fs.mkdir git_dir, '0755', (err) ->
          return done err if err
          git.init git_dir, (err) ->
            return done err if err
            repo = git git_dir
            done()

    after (done) ->
      fs.remove git_dir, done

    describe "with only a file", ->
      file = 'foo.txt'
      # given a new file
      before (done) ->
        fs.writeFile "#{git_dir}/#{file}", "cheese", (err) ->
          return done err if err?
          repo.add "#{git_dir}/#{file}", (err) ->
            return done err if err?
            repo.status (err, _status) ->
              status = _status
              done err

      it "was added", ->
        status.files.should.have.a.property file
        status.files[file].staged.should.be.true
        status.files[file].tracked.should.be.true
        status.files[file].type.should.eql 'A'

    describe "with no file and all option", ->
      file = 'bar.txt'
      # given a new file
      before (done) ->
        fs.writeFile "#{git_dir}/#{file}", "cheese", (err) ->
          return done err if err?
          repo.add [], A:true, (err) ->
            return done err if err?
            repo.status (err, _status) ->
              status = _status
              done err

      it "was added", ->
        status.files.should.have.a.property file
        status.files[file].staged.should.be.true
        status.files[file].tracked.should.be.true
        status.files[file].type.should.eql 'A'

  describe "#sync", ->
    describe "when passed curried arguments", ->
      repo  = fixtures.branched
      remote = branch = ""

      before ->
        sinon.stub repo, "git"
        .callsFake (command, opts, args, callback) ->
          if command is "pull"
            remote = args[0]
            branch = args[1]
          callback? null
        sinon.stub repo, "status"
        .callsFake (callback) ->
          callback? null, clean: no

      after ->
        repo.git.restore()
        repo.status.restore()

      it "passes through the correct parameters when nothing is omitted", (done) ->
        repo.sync "github", "my-branch", ->
          remote.should.eql "github"
          branch.should.eql "my-branch"
          done()

      it "passes through the correct parameters when remote_name is omitted", (done) ->
        repo.sync "my-branch", ->
          remote.should.eql "origin"
          branch.should.eql "my-branch"
          done()

      it "passes through the correct parameters when remote_name and branch are omitted", (done) ->
        repo.sync ->
          remote.should.eql "origin"
          branch.should.eql "master"
          done()


  describe "#identify", ->
    describe "when asked to set the identity's name and email", ->
      repo  = fixtures.branched
      id    = '' + new Date().getTime()
      name  = "name-#{id}"
      email = "#{id}@domain"
      ident = null

      before (done) ->
        actor = new Actor(name, email)
        repo.identify actor, (err) ->
          done err if err
          repo.identity (err, _actor) ->
            ident = _actor
            done err

      after (done) ->
        exec "git checkout -- #{ repo.path }", done

      it "has correctly set them", ->
        ident.name.should.eql  name
        ident.email.should.eql email

  describe "#commits", ->

    describe "with a single commit", ->
      repo    = null
      commit  = null
      git_dir = __dirname + "/fixtures/junk_commit"

      # given a fresh new repo
      before (done) ->
        fs.remove git_dir, (err) ->
          return done err if err?
          fs.mkdir git_dir, '0755', (err) ->
            return done err if err?
            git.init git_dir, (err) ->
              return done err if err?
              repo = git(git_dir)
              fs.writeFileSync "#{git_dir}/foo.txt", "cheese"
              repo.identify new Actor('root', 'root@domain.net'), (err) ->
                return done err if err?
                repo.add "#{git_dir}/foo.txt", (err) ->
                  return done err if err?
                  repo.commit 'message with spaces',
                    author: 'Someone <someone@somewhere.com>'
                  , (err) ->
                    return done err if err?
                    repo.commits (err, _commits) ->
                      commit = _commits[0]
                      done err

      after (done) ->
        fs.remove git_dir, done

      it "has right message", (done) ->
        commit.message.should.eql 'message with spaces'
        commit.author.name.should.eql 'Someone'
        commit.author.email.should.eql 'someone@somewhere.com'
        done()

      it "has a tree", (done) ->
        commit.tree().should.be.an.instanceof Tree
        commit.tree().contents (err, child) ->
          return done err if err
          child.length.should.eql 1
          child[0].name.should.eql 'foo.txt'
          done()
    describe "with only a callback", ->
      repo    = fixtures.branched
      commits = null
      before (done) ->
        repo.commits (err, _commits) ->
          commits = _commits
          done err

      it "passes an Array", ->
        commits.should.be.an.instanceof Array

      it "is a list of commits", ->
        commits[0].id.should.eql "913318e66e9beed3e89e9c402c1d6585ef3f7e6f"
        commits[0].repo.should.eql repo
        commits[0].author.name.should.eql "sentientwaffle"
        commits[0].committer.name.should.eql "sentientwaffle"
        commits[0].authored_date.should.be.an.instanceof Date
        commits[0].committed_date.should.be.an.instanceof Date
        commits[0].parents().should.be.an.instanceof Array
        commits[0].message.should.eql "add a sub dir"

    describe "specify a branch", ->
      repo    = fixtures.branched
      commits = null
      before (done) ->
        repo.commits "something", (err, _commits) ->
          commits = _commits
          done err

      # The first commit ...
      it "is the latest commit", ->
        commits[0].message.should.eql "2"

      it "has a parent commit", ->
        commits[0].parents().should.have.lengthOf 1
        commits[0].parents()[0].id.should.eql commits[1].id

    describe "specify a tag", ->
      repo    = fixtures.tagged
      commits = null
      before (done) ->
        repo.commits "tag-1", (err, _commits) ->
          commits = _commits
          done err

      it "is the latest commit on the tag", ->
        commits[0].message.should.containEql "commit 5"

    describe "limit the number of commits", ->
      repo    = fixtures.tagged
      commits = null
      before (done) ->
        repo.commits "master", 2, (err, _commits) ->
          commits = _commits
          done err

      it "returns 2 commits", ->
        commits.should.have.lengthOf 2

    describe "skip commits", ->
      repo    = fixtures.tagged
      commits = null
      before (done) ->
        repo.commits "master", 1, 2, (err, _commits) ->
          commits = _commits
          done err

      it "returns 2 commits", ->
        commits[0].message.should.containEql "commit 4"

    describe "with or without gpg signature", ->
      repo    = fixtures.gpgsigned
      commits = null
      before (done) ->
        repo.commits "master", (err, _commits) ->
          commits = _commits
          done err

      it "has no gpgsig", ->
        commits[0].gpgsig.should.not.be.ok

      it "has gpgsig", ->
        commits[1].gpgsig.should.be.ok

      it "contains the correct signature", ->
        commits[1].gpgsig.should.equal """
        -----BEGIN#{" "}PGP#{" "}SIGNATURE-----
        #{" "}Version:#{" "}GnuPG#{" "}v2.0.22#{" "}(GNU/Linux)
        #{" "}
        #{" "}iQEcBAABAgAGBQJTQw8qAAoJEL0/h9tqDFPiP3UH/RwxUS90+6DEkThcKMmV9H4K
        #{" "}dr+D0H0z2ViMq3AHSmCydv5dWr3bupl2XyaLWWuRCxAJ78xuf98qVRIBfT/FKGeP
        #{" "}fz+GtXkv3naCD12Ay6YiwfxSQhxFiJtRwP5rla2i7hlV3BLFPYCWTtL8OLF4CoRm
        #{" "}7aF5EuDr1x7emEDyu1rf5E59ttSIySuIw0J1mTjrPCkC6lsowzTJS/vaCxZ3e7fN
        #{" "}iZE6VEWWY/iOxd8foJH/VZ3cfNKjfi8+Fh8t7o9ztjYTQAOZUJTn2CHB7Wkyr0Ar
        #{" "}HNM3v26gPFpb7UkHw0Cq2HWNV/Z7cbQc/BQ4HmrmuBPB6SWNOaBN751BbQKnPcA=
        #{" "}=IusH
        #{" "}-----END#{" "}PGP#{" "}SIGNATURE-----"""

  describe "#tree", ->
    repo = fixtures.branched
    describe "master", ->
      it "is a Tree", ->
        repo.tree().should.be.an.instanceof Tree

      it "checks out branch:master", (done) ->
        repo.tree().blobs (err, blobs) ->
          blobs[0].data (err, data) ->
            data.should.containEql "Bla"
            data.should.not.containEql "Bla2"
            done err

    describe "specific branch", ->
      it "is a Tree", ->
        repo.tree("something").should.be.an.instanceof Tree

      it "checks out branch:something", (done) ->
        repo.tree("something").blobs (err, blobs) ->
          blobs[0].data (err, data) ->
            data.should.containEql "Bla2"
            done err


  describe "#diff", ->
    repo = fixtures.branched
    describe "between 2 branches", ->
      diffs = null
      before (done) ->
        repo.diff "something", "master", (err, _diffs) ->
          diffs = _diffs
          done err

      it "is passes an Array of Diffs", ->
        diffs.should.be.an.instanceof Array
        diffs[0].should.be.an.instanceof Diff

      # The first diff...
      it "modifies the README.md file", ->
        diffs[0].a_path.should.eql "README.md"
        diffs[0].b_path.should.eql "README.md"

      # The second diff...
      it "creates some/hi.txt", ->
        diffs[1].new_file.should.be.true
        diffs[1].b_path.should.eql "some/hi.txt"


  describe "#remotes", ->
    describe "in a repository with remotes", ->
      repo    = fixtures.remotes
      remotes = null
      before (done) ->
        repo.remotes (err, _remotes) ->
          remotes = _remotes
          done err

      it "is an Array of Refs", ->
        remotes.should.be.an.instanceof Array
        remotes[0].should.be.an.instanceof Ref

      it "contains the correct Refs", ->
        remotes[0].commit.id.should.eql "bdd3996d38d885e18e5c5960df1c2c06e34d673f"
        remotes[0].name.should.eql "origin/HEAD"
        remotes[1].commit.id.should.eql "bdd3996d38d885e18e5c5960df1c2c06e34d673f"
        remotes[1].name.should.eql "origin/master"

    describe "when there are no remotes", ->
      repo = fixtures.branched
      it "is an empty Array", ->
        repo.remotes (err, remotes) ->
          remotes.should.eql []


  describe "#remote_list", ->
    describe "in a repository with remotes", ->
      repo    = fixtures.remotes
      remotes = null
      before (done) ->
        repo.remote_list (err, _remotes) ->
          remotes = _remotes
          done err

      it "is a list of remotes", ->
        remotes.should.have.lengthOf 1
        remotes[0].should.eql "origin"

    describe "when there are no remotes", ->
      repo = fixtures.branched
      it "is an empty Array", ->
        repo.remote_list (err, remotes) ->
          remotes.should.eql []


  describe "#tags", ->
    describe "a repo with tags", ->
      repo = fixtures.tagged
      tags = null
      before (done) ->
        repo.tags (err, _tags) ->
          tags = _tags
          done err

      it "is an Array of Tags", ->
        tags.should.be.an.instanceof Array
        tags[0].should.be.an.instanceof Tag

      it "is the correct tag", ->
        tags[0].name.should.eql "tag-1"

    describe "a repo without tags", ->
      repo = fixtures.branched
      it "is an empty array", (done) ->
        repo.tags (err, tags) ->
          tags.should.eql []
          done err

  describe "#create_tag", ->
    repo    = null
    git_dir = __dirname + "/fixtures/junk_create_tag"

    before (done) ->
      fs.remove git_dir, (err) ->
        return done err if err
        fs.mkdir git_dir, 0o755, (err) ->
          return done err if err
          git.init git_dir, (err) ->
            return done err if err
            repo = git(git_dir)
            repo.identify new Actor('name', 'em@il'), ->
              fs.writeFileSync "#{git_dir}/foo.txt", "cheese"
              repo.add "#{git_dir}/foo.txt", (err) ->
                return done err if err
                repo.commit "initial commit", {all: true}, done

    after (done) ->
      fs.remove git_dir, done

    it "creates a tag", (done) ->
      repo.create_tag "foo", done

  describe "#delete_tag", ->
    describe "deleting a tag that does not exist", ->
      repo = fixtures.branched
      it "passes an error", (done) ->
        repo.delete_tag "nonexistant-tag", (err) ->
          should.exist err
          done()


  describe "#branches", ->
    repo     = fixtures.branched
    branches = null
    before (done) ->
      repo.branches (err, _branches) ->
        branches = _branches
        done err

    it "is an Array of Heads", ->
      branches.should.be.an.instanceof Array
      branches[0].should.be.an.instanceof Head

    it "has the correct branches", ->
      branches[0].name.should.eql "master"
      branches[1].name.should.eql "something"


  describe "#branch", ->
    describe "when a branch name is given", ->
      repo   = fixtures.branched
      branch = null
      before (done) ->
        repo.branch "something", (err, b) ->
          branch = b
          done err

      it "is a Head", ->
        branch.should.be.an.instanceof Head

      it "has the correct name", ->
        branch.name.should.eql "something"

    describe "when no branch name is given", ->
      repo   = fixtures.branched
      branch = null
      before (done) ->
        repo.branch (err, b) ->
          branch = b
          done err

      it "has the correct name", ->
        branch.name.should.eql "master"

    describe "an invalid branch", ->
      repo = fixtures.branched
      it "passes an error", (done) ->
        repo.branch "nonexistant-branch", (err, b) ->
          should.exist err
          should.not.exist b
          done()


    describe "current branch is (no branch)", ->
      repo = fixtures.noBranch
      it "passes an error", (done) ->
        repo.branch (err, b) ->
          should.exist err
          should.not.exist b
          done()


  describe "#delete_branch", ->
    describe "a branch that does not exist", ->
      repo = fixtures.branched
      it "passes an error", (done) ->
        repo.delete_branch "nonexistant-branch", (err) ->
          should.exist err
          done()

  describe "#clean", ->
    repo    = null
    git_dir = __dirname + "/fixtures/junk_clean"
    status  = null
    file    = "bla.txt"
    dir     = 'blah'

    # given a fresh new repo
    beforeEach (done) ->
      status = null
      fs.remove git_dir, (err) ->
        return done err if err
        fs.copy "#{__dirname}/fixtures/clean", "#{git_dir}", (err) ->
          return done err if err
          fs.rename "#{git_dir}/git.git", "#{git_dir}/.git", (err) ->
            return done err if err
            git.init git_dir, (err) ->
              repo = git git_dir
              fs.writeFile "#{git_dir}/#{file}", "hello", (err) ->
                return done err if err?
                fs.mkdir "#{git_dir}/#{dir}", (err) ->
                  done err

    after (done) ->
      fs.remove git_dir, (err) ->
        done err

    describe "clean with no args shouldn't do anything", ->
      beforeEach (done) ->
        repo.clean ->
          repo.status (err, _status) ->
            status = _status
            done err

      it "leaves the untracked file alone", ->
        fs.existsSync("#{git_dir}/iamuntracked").should.be.true
        fs.existsSync("#{git_dir}/iamuntracked/untracked.txt").should.be.true
        fs.existsSync("#{git_dir}/#{dir}").should.be.true
        status.files.should.have.a.property file
        status.files[file].staged.should.be.false
        status.files[file].tracked.should.be.false
        status.files[file].should.not.have.a.property 'type'

    describe "clean --force", ->
      beforeEach (done) ->
        repo.clean {force: true}, ->
          repo.status (err, _status) ->
            status = _status
            done err

      it "should remove the file but not the directory", ->
        status.files.should.not.have.a.property file
        fs.existsSync("#{git_dir}/#{dir}").should.be.true
        fs.existsSync("#{git_dir}/iamuntracked").should.be.true

        # git does not clean untracked files in untracked directories
        fs.existsSync("#{git_dir}/iamuntracked/untracked.txt").should.be.true

    describe "clean -df", ->
      beforeEach (done) ->
        repo.clean {force: true, d: true}, ->
          repo.status (err, _status) ->
            status = _status
            done err

      it "removes the file and directory", ->
        status.files.should.not.have.a.property file
        fs.existsSync("#{git_dir}/#{dir}").should.be.false
        fs.existsSync("#{git_dir}/iamuntracked").should.be.false
        fs.existsSync("#{git_dir}/iamuntracked/untracked.txt").should.be.false

  describe "#reset", ->
    repo    = null
    git_dir = __dirname + "/fixtures/junk_reset"
    status  = null
    file    = "bla.txt"

    # given a fresh new repo
    beforeEach (done) ->
      status = null
      fs.remove git_dir, (err) ->
        return done err if err
        fs.copy "#{__dirname}/fixtures/reset", "#{git_dir}", (err) ->
          return done err if err
          fs.rename "#{git_dir}/git.git", "#{git_dir}/.git", (err) ->
            return done err if err
            git.init git_dir, (err) ->
              repo = git git_dir
              fs.writeFile "#{git_dir}/#{file}", "hello", (err) ->
                return done err if err?
                repo.add "#{git_dir}/#{file}", (err) ->
                  done err

    after (done) ->
      fs.remove git_dir, (err) ->
        done err

    describe "reset without specific treeish (defaults to HEAD)", ->
      describe "reset (--mixed)", ->
        beforeEach (done) ->
          repo.reset ->
            repo.status (err, _status) ->
              status = _status
              done err

        it "removes the file from index, leaves it in working tree", ->
          status.files.should.have.a.property file
          status.files[file].staged.should.be.false
          status.files[file].tracked.should.be.false
          status.files[file].should.not.have.a.property 'type'

      describe "reset --soft", ->
        beforeEach (done) ->
          repo.reset {soft: true}, ->
            repo.status (err, _status) ->
              status = _status
              done err

        it "leaves the added file in the index", ->
          status.files.should.have.a.property file
          status.files[file].staged.should.be.true
          status.files[file].tracked.should.be.true
          status.files[file].type.should.eql 'A'

      describe "reset --hard", ->
        beforeEach (done) ->
          repo.reset {hard: true}, ->
            repo.status (err, _status) ->
              status = _status
              done err

        it "removes the file from index and working tree", ->
          status.files.should.not.have.a.property file

    describe "reset to specific treeish", ->
      describe "reset (--mixed) HEAD~1", ->
        beforeEach (done) ->
          repo.reset 'HEAD~1', ->
            repo.status (err, _status) ->
              status = _status
              done err

        it "resets to HEAD~1, changes stay in the working tree", ->
          status.files.should.have.a.property file
          status.files[file].staged.should.be.false
          status.files[file].tracked.should.be.false
          status.files[file].should.not.have.a.property 'type'

          status.files.should.have.a.property 'rawr.txt'
          status.files['rawr.txt'].staged.should.be.false
          status.files['rawr.txt'].tracked.should.be.false
          status.files['rawr.txt'].should.not.have.a.property 'type'

      describe "reset --soft HEAD~1", ->
        beforeEach (done) ->
          repo.reset 'HEAD~1', {soft: true}, ->
            repo.status (err, _status) ->
              status = _status
              done err

        it "resets to HEAD~1, changes stay in the index and working tree", ->
          status.files.should.have.a.property file
          status.files[file].staged.should.be.true
          status.files[file].tracked.should.be.true
          status.files[file].type.should.eql 'A'

          status.files.should.have.a.property 'rawr.txt'
          status.files['rawr.txt'].staged.should.be.true
          status.files['rawr.txt'].tracked.should.be.true
          status.files['rawr.txt'].type.should.eql 'AM'

      describe "reset --hard HEAD~1", ->
        beforeEach (done) ->
          repo.reset 'HEAD~1', {hard: true}, ->
            repo.status (err, _status) ->
              status = _status
              done err

        it "resets to HEAD~1, all changes get discarded completely", ->
          status.files.should.not.have.a.property file
          status.files.should.not.have.a.property 'rawr.txt'

  describe "#checkout", ->
    repo    = null
    head    = null
    git_dir = __dirname + "/fixtures/junk_checkout"

    # given a fresh new repo
    beforeEach (done) ->
      fs.remove git_dir, (err) ->
        return done err if err
        fs.copy "#{__dirname}/fixtures/reset", "#{git_dir}", (err) ->
          return done err if err
          fs.rename "#{git_dir}/git.git", "#{git_dir}/.git", (err) ->
            git.init git_dir, (err) ->
              return done err if err
              repo = git git_dir
              done()

    after (done) ->
      fs.remove git_dir, (err) ->
        done err

    describe "an existing branch", ->
      beforeEach (done) ->
        repo.checkout "feature/foo", {b: true}, (err) ->
          return done err if err?
          repo.checkout "master", (err) ->
            return done err if err?
            repo.branch (err, _head) ->
              head = _head
              done err

      it "should succeed", ->
        head.name.should.equal "master"

    describe "and create new branch", ->
      beforeEach (done) ->
        repo.checkout "feature/foo", {b: true}, (err) ->
          return done err if err?
          repo.branch (err, _head) ->
            head = _head
            done err

      it "should succeed", ->
        head.name.should.equal "feature/foo"

  describe "#checkoutFile", ->
    repo    = null
    git_dir = __dirname + "/fixtures/junk_checkoutFile"
    status  = null
    file    = "bla.txt"

    # given a fresh new repo
    beforeEach (done) ->
      status = null
      fs.remove git_dir, (err) ->
        return done err if err
        fs.copy "#{__dirname}/fixtures/reset", "#{git_dir}", (err) ->
          return done err if err
          fs.rename "#{git_dir}/git.git", "#{git_dir}/.git", (err) ->
            git.init git_dir, (err) ->
              return done err if err
              repo = git git_dir
              fs.writeFile "#{git_dir}/#{file}", "hello", (err) ->
                return done err if err?
                repo.add "#{git_dir}/#{file}", (err) ->
                  done err

    after (done) ->
      fs.remove git_dir, (err) ->
        done err

    describe "passing no explicit files", ->
      beforeEach (done) ->
        repo.checkoutFile ->
          repo.status (err, _status) ->
            status = _status
            done err

      it "discards changes in the working tree for all files", ->
        status.files.should.have.a.property file
        status.files[file].staged.should.be.true
        status.files[file].tracked.should.be.true
        status.files[file].type.should.eql 'A'

        status.files.should.have.a.property 'rawr.txt'
        status.files['rawr.txt'].staged.should.be.true
        status.files['rawr.txt'].tracked.should.be.true
        status.files['rawr.txt'].type.should.eql 'M'

    describe "passing an explicit file", ->
      beforeEach (done) ->
        repo.checkoutFile 'rawr.txt', ->
          repo.status (err, _status) ->
            status = _status
            done err

      it "discard changes to the specified file", ->
        status.files.should.have.a.property 'rawr.txt'
        status.files['rawr.txt'].staged.should.be.true
        status.files['rawr.txt'].tracked.should.be.true
        status.files['rawr.txt'].type.should.eql 'M'
