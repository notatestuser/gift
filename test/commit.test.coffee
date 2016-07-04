should   = require 'should'
fixtures = require './fixtures'
git      = require '../src'
Commit   = require '../src/commit'
Tree     = require '../src/tree'

describe "Commit", ->
  describe "#tree", ->
    repo = git "#{__dirname}/fixtures/branched"
    tree = null
    before (done) ->
      repo.commits "master", (err, commits) ->
        tree = commits[0].tree()
        done err

    it "passes a tree", ->
      tree.should.be.an.instanceof Tree


  describe "#parents", ->
    repo    = fixtures.branched
    parents = null
    parent  = null
    before (done) ->
      repo.commits "something", (err, commits) ->
        parents = commits[0].parents()
        parent  = commits[1]
        done err

    it "is an Array of Commits", ->
      parents.should.be.an.instanceof Array
      parents[0].should.be.an.instanceof Commit

    it "has the parent commit", ->
      parents[0].id.should.eql parent.id

  describe "#describe", ->
    repo   = fixtures.branched
    commit = null
    before (done) ->
      repo.commits "something", (err, commits) ->
        commit = commits[0]
        done err

    it "should be a long description", (done) ->
      repo.commits "something", (err, commits) ->
        commit.describe 'all', (err, description) ->
          # long descriptions have a '-g' in them to separate the sha-1
          (/-g/.test description).should.eql true
          done err
