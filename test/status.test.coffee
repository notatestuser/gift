should   = require 'should'
fixtures = require './fixtures'
git      = require '../src'
Status   = require '../src/status'

GIT_STATUS = """
     M cheese.txt
    D  crackers.txt
    M  file.txt
    ?? pickles.txt
  """
GIT_STATUS_CLEAN = ""
GIT_STATUS_NOT_CLEAN = """
    A  lib/index.js
     M npm-shrinkwrap.json
     M package.json
  """

describe "Status", ->
  describe "()", ->
    describe "when there are no changes", ->
      repo   = fixtures.status
      status = new Status.Status repo
      status.parse GIT_STATUS_CLEAN
      
      it "is clean", ->
        status.clean.should.be.true
      
    describe "when there are changes", ->
      repo   = fixtures.status
      status = new Status.Status repo
      status.parse GIT_STATUS_NOT_CLEAN
      it "is not clean", ->
        status.clean.should.be.false

    describe "when there are changes", ->
      repo   = fixtures.status
      status = new Status.Status repo
      status.parse GIT_STATUS
      
      it "has a modified staged file", ->
        status.files["file.txt"].staged.should.be.true
        status.files["file.txt"].type.should.eql "M"
        status.files["file.txt"].tracked.should.be.true
      
      it "has a modified unstaged file", ->
        status.files["cheese.txt"].staged.should.be.false
        status.files["cheese.txt"].type.should.eql "M"
        status.files["cheese.txt"].tracked.should.be.true
      
      it "has a deleted file", ->
        status.files["crackers.txt"].staged.should.be.true
        status.files["crackers.txt"].type.should.eql "D"
        status.files["crackers.txt"].tracked.should.be.true
      
      it "has an untracked file", ->
        status.files["pickles.txt"].tracked.should.be.false
        should.not.exist status.files["pickles.txt"].type
      
      it "is not clean", ->
        status.clean.should.be.false
