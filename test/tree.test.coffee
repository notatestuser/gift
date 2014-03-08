should    = require 'should'
fixtures  = require './fixtures'
git       = require '../src'
Tree      = require '../src/tree'
Blob      = require '../src/blob'
Submodule = require '../src/submodule'

describe "Tree", ->
  describe "#contents", ->
    describe "simple", ->
      repo     = fixtures.branched
      tree     = repo.tree()
      contents = null
      
      before (done) ->
        tree.contents (err, _contents) ->
          contents = _contents
          done err
      
      it "is an Array", ->
        contents.should.be.an.instanceof Array
      
      it "contains a Blob", ->
        contents[0].should.be.an.instanceof Blob
        contents[0].name.should.eql "README.md"
      
      it "contains a Tree", ->
        contents[1].should.be.an.instanceof Tree
        contents[1].name.should.eql "some"
    
    describe "with submodules", ->
      repo     = fixtures.submodule
      tree     = repo.tree()
      contents = null
      
      before (done) ->
        tree.contents (err, _contents) ->
          contents = _contents
          done err
      
      it "contains a Submodule", (done) ->
        contents[2].should.be.an.instanceof Submodule
        contents[2].name.should.eql "spoon-knife"
        contents[2].url (err, url) ->
          url.should.eql "git://github.com/octocat/Spoon-Knife.git"
          done err
  
  
  describe "#blobs", ->
    repo  = fixtures.branched
    tree  = repo.tree()
    blobs = null
    
    before (done) ->
      tree.blobs (err, _blobs) ->
        blobs = _blobs
        done err
    
    it "has only 1 item", ->
      blobs.should.have.lengthOf 1
    
    it "contains a Blob", ->
      blobs[0].should.be.an.instanceof Blob
      blobs[0].name.should.eql "README.md"
  
  
  describe "#trees", ->
    repo  = fixtures.branched
    tree  = repo.tree()
    trees = null
    
    before (done) ->
      tree.trees (err, _trees) ->
        trees = _trees
        done err
    
    it "has only 1 item", ->
      trees.should.have.lengthOf 1
    
    it "contains a Tree", ->
      trees[0].should.be.an.instanceof Tree
      trees[0].name.should.eql "some"
  
  
  describe "#find", ->
    repo = fixtures.branched
    tree = repo.tree()
    describe "find a file", ->
      blob = null
      before (done) ->
        tree.find "README.md", (err, _blob) ->
          blob = _blob
          done err
      
      it "finds the Blob", ->
        blob.should.be.an.instanceof Blob
        blob.name.should.eql "README.md"
    
    describe "find a directory", ->
      subtree = null
      before (done) ->
        tree.find "some", (err, _tree) ->
          subtree = _tree
          done err
      
      it "finds the Tree", ->
        subtree.should.be.an.instanceof Tree
        subtree.name.should.eql "some"
        
    describe "find inside a directory", ->
      blob = null
      before (done) ->
        tree.find "some/hi.txt", (err, _blob) ->
          blob = _blob
          done err
      
      it "finds the Blob", ->
        blob.should.be.an.instanceof Blob
        blob.name.should.eql "hi.txt"

    #describe "find inside nested directory", ->
    #  blob = null
    #  before (done) ->
    #    tree.find "some/nested/nested_file.txt", (err, _blob) ->
    #      blob = _blob
    #      done err

    #  it "finds the Blob", ->
    #    blob.should.be.an.instancedof Blob
    #    blob.name.should.eql "nested_file.txt"

    describe "find a nonexistant file", ->
      subtree = null
      before (done) ->
        tree.find "nonexistant", (err, _tree) ->
          subtree = _tree
          done err
      
      it "is null", ->
        should.not.exist subtree

