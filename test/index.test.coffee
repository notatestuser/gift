should = require 'should'
git    = require '../src'
Repo   = require '../src/repo'
fs     = require "fs"
{exec} = require 'child_process'

describe "git", ->
  describe "()", ->
    repo = git "#{__dirname}/fixtures/simple"
    it "returns a Repo", ->
      repo.should.be.an.instanceof Repo

  describe "init()", ->
    repo = null
    newRepositoryDir = "#{__dirname}/fixtures/new"
    before (done) ->
      fs.mkdirSync newRepositoryDir
      git.init newRepositoryDir, (err, _repo) ->
        repo = _repo
        done err
    it "inits a Repo", ->
      repo.should.be.an.instanceof Repo
      bare = repo.bare || false
      bare.should.be.false
    after (done) ->
      exec "rm -rf #{newRepositoryDir}", done

  describe "init() bare", ->
    repo = null
    newRepositoryDir = "#{__dirname}/fixtures/bare"
    before (done) ->
      fs.mkdirSync newRepositoryDir
      git.init newRepositoryDir, true, (err, _repo) ->
        repo = _repo
        done err
    it "inits a bare Repo", ->
      repo.should.be.an.instanceof Repo
      bare = repo.bare || false
      bare.should.be.true
    after (done) ->
      exec "rm -rf #{newRepositoryDir}", done

  describe "clone()", ->
    @timeout 30000
    repo = null
    newRepositoryDir = "#{__dirname}/fixtures/clone"
    before (done) ->
      git.clone "https://github.com/notatestuser/gift.git", newRepositoryDir, (err, _repo) ->
        repo = _repo
        done err
    it "clone a repository", (done) ->
      repo.should.be.an.instanceof Repo
      repo.remote_list (err, remotes) ->
        remotes.should.have.length 1
        done()
    after (done) ->
      exec "rm -rf #{newRepositoryDir}", done

  describe "pull()", ->
    @timeout 30000
    repo = null
    RepositoryDir = "#{__dirname}/fixtures/clone"
    before (done) ->
      git.clone "https://github.com/notatestuser/gift.git", RepositoryDir, (err, _repo) ->
      git.pull '', '', RepositoryDir, (err, _repo) ->
        repo = _repo
        done err
    it "pull a repository", (done) ->
      repo.should.be.an.instanceof Repo
      done()
    after (done) ->
      exec "rm -rf #{RepositoryDir}", done
