fs     = require 'fs'
Commit = require './commit'

exports.Ref = class Ref
  constructor: (@name, @commit) ->
    {@repo} = @commit

  # Public: Get a String representation of the Ref.
  toString: ->
    "#<Ref '#{@name}'>"

  # Internal: Find all refs.
  #
  # options - (optional).
  #
  # Returns Array of Ref.
  @find_all: (repo, type, RefClass, callback) ->
    repo.git.refs type, {}, (err, text) ->
      return callback err if err
      names = []
      ids   = []
      for ref in text.split("\n")
        continue if !ref
        [name, id] = ref.split(' ')
        names.push name
        ids.push id

      Commit.find_commits repo, ids, (err, commits) ->
        return callback err if err
        refs = []
        for name, i in names
          refs.push new RefClass name, commits[i]
        return callback null, refs


exports.Head = class Head extends Ref
  @find_all: (repo, callback) ->
    Ref.find_all repo, "head", Head, callback

  @current: (repo, callback) ->
    fs.readFile "#{repo.dot_git}/HEAD", "utf8", (err, data) ->
      return callback err if err

      ref = /ref: refs\/heads\/([^\s]+)/.exec data
      # When the current branch check out to a commit, instaed of a branch name.
      return callback new Error "Current branch is not a valid branch." if !ref

      [m, branch] = ref
      fs.readFile "#{repo.dot_git}/refs/heads/#{branch}", "utf8", (err, id) ->
        Commit.find repo, id.trim(), (err, commit) ->
          return callback err if err
          return callback null, (new Head branch, commit)
