_      = require 'underscore'
cmd    = require './git'
Actor  = require './actor'
Commit = require './commit'
Config = require './config'
Tree   = require './tree'
Diff   = require './diff'
Tag    = require './tag'
Status = require './status'

{Ref, Head} = require './ref'

module.exports = class Repo
  constructor: (@path, @bare) ->
    if @bare
      @dot_git = @path
    else
      @dot_git = "#{@path}/.git"
    @git  = cmd @path, @dot_git


  # Public: Get the commit identity for this repository.
  #
  # callback - Receives `(err, actor)`, where `actor` is an Actor.
  #
  identity: (callback) ->
    # git config user.email
    @git "config", {}, ["user.email"]
    , (err, stdout = '') =>
      return callback err if err
      email = stdout?.trim()
      # git config user.name
      @git "config", {}, ["user.name"]
      , (err, stdout = '') =>
        return callback err if err
        name = stdout?.trim()
        return callback null, new Actor(name, email)


  # Public: Set your account's default identity for commits.
  #
  # actor    - An instance of Actor.
  # callback - Receives `(err)`.
  #
  identify: (actor, callback) ->
    # git config user.email "you@example.com"
    @git "config", {}, ["user.email", "#{actor.email}"], (err) =>
      return callback err if err
      # git config user.name "Your Name"
      @git "config", {}, ["user.name", "#{actor.name}"], (err) =>
        return callback err if err
        return callback null


  # Public: Get a list of commits.
  #
  # treeish  - String  (optional).
  # limit    - Integer (optional).
  # skip     - Integer (optional).
  # callback - Function which receives `(err, commits)`, where `commits` is
  #            an Array of Commits.
  #
  # Examples
  #
  #   # Get the 10 most recent commits to master.
  #   repo.commits (err, commits) ->
  #
  #   # Or to a different tag or branch.
  #   repo.commits "v0.0.3", (err, commits) ->
  #
  #   # Limit the maximum number of commits returned.
  #   repo.commits "master", 30, (err, commits) ->
  #
  #   # Skip some (for pagination):
  #   repo.commits "master", 30, 30, (err, commits) ->
  #
  #   # Do not limit commits amount
  #   repo.commits "master", -1, (err, commits) ->
  #
  commits: (start, limit, skip, callback) ->
    [skip,  callback] = [callback, skip]  if !callback
    [limit, callback] = [callback, limit] if !callback
    [start, callback] = [callback, start] if !callback
    throw new Error "a callback is required" if !callback
    start ?= "master"
    limit ?= 10
    skip  ?= 0
    options = {skip}

    if limit != -1
      options["max-count"] = limit

    Commit.find_all this, start, options, callback


  # Internal: Returns current commit id
  #
  # callback - Receives `(err, id)`.
  #
  current_commit_id: (callback) ->
    @git "rev-parse HEAD", {}, []
    , (err, stdout, stderr) =>
      return callback err if err
      return callback null, _.first stdout.split "\n"


  # Public:
  #
  # callback - Receives `(err, commit)`
  #
  current_commit: (callback) ->
    @current_commit_id (err, commit_id) =>
      return callback err if err
      Commit.find this, commit_id, callback


  # Public: The tree object for the treeish or master.
  #
  # treeish - String treeish (such as a branch or tag) (optional).
  #
  # Returns Tree.
  tree: (treeish="master") ->
    return new Tree this, treeish


  # Public: Get the difference between the trees.
  #
  # commitA  - A Commit or String commit id.
  # commitB  - A Commit or String commit id.
  # paths    - A list of String paths to restrict the difference to (optional).
  # options  - An object of options to pass to git diff (optional)
  # callback - A Function which receives `(err, diffs)`.
  #
  # Possible forms of the method:
  #
  # diff(commitA, commitB, callback)
  # diff(commitA, commitB, paths, callback)
  # diff(commitA, commitB, options, callback)
  # diff(commitA, commitB, paths, options, callback)
  #
  diff: (commitA, commitB) ->
    [paths, options] = [[], {}]
    if arguments.length is 3
      callback = arguments[2]
    else if arguments.length is 4
      callback = arguments[3]
      if arguments[2] instanceof Array
        paths = arguments[2]
      else if arguments[2] instanceof Object
        options = arguments[2]
    else if arguments.length is 5
      [paths, options, callback] = Array.prototype.slice.call(arguments, 2)

    commitA = commitA.id if _.isObject(commitA)
    commitB = commitB.id if _.isObject(commitB)
    @git "diff", options, _.flatten([commitA, commitB, "--", paths])
    , (err, stdout, stderr) =>
      return callback err if err
      if _.has(options, 'raw')
        return callback err, Diff.parse_raw(this, stdout)
      else
        return callback err, Diff.parse(this, stdout)


  # Public: Get the repository's remotes.
  #
  # callback - Receives `(err, remotes)`.
  #
  remotes: (callback) ->
    Ref.find_all this, "remote", Ref, callback

  # Public: List the repository's remotes.
  #
  # callback - Receives `(err, names)`.
  #
  remote_list: (callback) ->
    @git.list_remotes callback

  # Public: Add a remote.
  #
  # name     - String name of the remote.
  # url      - String url of the remote.
  # callback - Receives `(err)`
  #
  remote_add: (name, url, callback) ->
    @git "remote", {}, ["add", name, url]
    , (err, stdout, stderr) ->
      callback err

  # Public: Remove a remote.
  #
  # name     - String name of the remote.
  # callback - Receives `(err)`
  #
  remote_remove: (name, callback) ->
    @git "remote", {}, ["rm", name]
    , (err, stdout, stderr) ->
      callback err

  # Public: `git fetch <name>`.
  #
  # name     - String name of the remote
  # callback - Receives `(err)`.
  #
  remote_fetch: (name, callback) ->
    @git "fetch", {}, name
    , (err, stdout, stderr) ->
      callback err

  # Public: `git push <name>`.
  #
  # name     - String name of the remote
  # branch   - (optional) Branch to push
  # callback - Receives `(err)`.
  #
  remote_push: (name, branch, callback) ->
    if !callback
      callback = branch
      args = name
    else
      args = [name, branch]

    @git "push", {}, args
    , (err, stdout, stderr) ->
      callback err

  # Public: `git merge <name>`.
  #
  # name     - String name of the source
  # callback - Receives `(err)`.
  #
  merge: (name, callback) ->
    @git "merge", {}, name
    , (err, stdout, stderr) ->
      callback err

  # Public: Get the repository's status (`git status`).
  #
  # callback - Receives `(err, status)`
  #
  status: (callback) ->
    return Status(this, callback)

  # Public: Show information about files in the index and the
  #         working tree.
  #
  # options  - An Object of command line arguments to pass to
  #            `git ls-files` (optional).
  # callback - Receives `(err,stdout)`.
  #
  ls_files: (options, callback) ->
    [options, callback] = [callback, options] if !callback
    @git "ls-files", options
    , (err, stdout, stderr) =>
      return callback err if err
      return callback null, @parse_lsFiles stdout,options


  config: (callback) ->
    return Config(this, callback)


  # Public: Get the repository's tags.
  #
  # callback - Receives `(err, tags)`.
  #
  tags: (callback) ->
    Tag.find_all this, callback

  # Public: Create a tag.
  #
  # name     - String
  # options  - An Object of command line arguments to pass to
  #            `git tag` (optional).
  # callback - Receives `(err)`.
  #
  create_tag: (name, options, callback) ->
    [options, callback] = [callback, options] if !callback
    @git "tag", options, [name], callback

  # Public: Delete the tag.
  #
  # name     - String
  # callback - Receives `(err)`.
  #
  delete_tag: (name, callback) ->
    @git "tag", {d: name}, callback


  # Public: Get a list of branches.
  #
  # callback - Receives `(err, heads)`.
  #
  branches: (callback) ->
    Head.find_all this, callback

  # Public: Create a branch with the given name.
  #
  # name     - String name of the new branch.
  # callback - Receives `(err)`.
  #
  create_branch: (name, callback) ->
    @git "branch", {}, name, (err, stdout, stderr) ->
      return callback err

  # Public: Delete the branch with the given name.
  #
  # name     - String name of the branch to delete.
  # callback - Receives `(err)`.
  #
  delete_branch: (name, callback) ->
    @git "branch", {d: true}, name, (err, stdout, stderr) ->
      return callback err

  # Public: Get the Branch with the given name.
  #
  # name     - String (optional). By default, get the current branch.
  # callback - Receives `(err, head)`
  #
  branch: (name, callback) ->
    [name, callback] = [callback, name] if !callback
    if !name
      Head.current this, callback
    else
      @branches (err, heads) ->
        return callback err if err
        for head in heads
          return callback null, head if head.name == name
        return callback new Error "No branch named '#{name}' found"


  # Public: Checkout the treeish.
  checkout: (treeish, callback) ->
    @git "checkout", {}, treeish, callback

  # Public: Reset the git repo.
  #
  # treeish  - The {String} to reset to.
  # options  - The {Object} containing one of the following items:
  #   :soft  - {Boolean)
  #   :mixed - {Boolean) When no other option given git defaults to 'mixed'.
  #   :hard  - {Boolean)
  #   :merge - {Boolean)
  #   :keep  - {Boolean)
  # callback - The {Function} to callback.
  #
  reset: (treeish, options, callback) ->
    [options, callback] = [callback, options] if !callback
    [treeish, callback] = [callback, treeish] if !callback
    [treeish, options]  = [options, treeish]  if typeof treeish is 'object'
    treeish ?= 'HEAD'
    options ?= {}

    @git "reset", options, treeish, callback

  # Public: Checkout file(s) to the index
  #
  # files    - Array of String paths; or a String path. If you want to
  #            checkout all files pass '.'.'
  # options  - Object (optional).
  #            "force" - Boolean
  # callback - Receives `(err)`.
  #
  checkoutFile: (files, options, callback) ->
    [options, callback] = [callback, options] if !callback
    [files, callback]   = [callback, files]   if !callback
    [files, options]    = [options, files]    if typeof files is 'object'
    options ?= {}
    files ?= '.'
    files = [files] if _.isString files
    @git "checkout", options, _.flatten(['--', files]), callback

  # Public: Commit some code.
  #
  # message  - String
  # options  - Object (optional).
  #            "amend" - Boolean
  #            "all"   - Boolean
  #            "author"- String formated like: A U Thor <author@example.com>
  # callback - Receives `(err)`.
  #
  commit: (message, options, callback) ->
    [options, callback] = [callback, options] if !callback
    options ?= {}
    options = _.extend options, {m: "#{message}"}
    # add quotes around author
    options.author = "#{options.author}" if options.author?
    @git "commit", options, callback

  # Public: Add files to the index.
  #
  # files    - Array of String paths; or a String path.
  # options  - Object (optional).
  #            "all"   - Boolean
  # callback - Receives `(err)`.
  #
  add: (files, options, callback) ->
    [options, callback] = [callback, options] if !callback
    options ?= {}
    files = [files] if _.isString files
    @git "add", options, files, callback

  # Public: Remove files from the index.
  #
  # files    - Array of String paths; or a String path.
  # options  - Object (optional).
  #            "recursive" - Boolean
  # callback - Receives `(err)`.
  #
  remove: (files, options, callback) ->
    [options, callback] = [callback, options] if !callback
    options ?= {}
    files = [files] if _.isString files
    @git "rm", options, files, callback

  # Public: Revert the given commit.
  revert: (sha, callback) ->
    @git "revert", {}, sha, callback


  # Public: Sync the current branch with the remote.
  #
  # Arguments: ([[remote_name, ]branch_name, ]callback)
  #
  # remote_name - String (optional).
  # branch_name - String.
  # callback - Receives `(stderr)`.
  #
  sync: (remote_name, branch_name, callback) ->

    # handle 'curried' arguments
    [remote, branch] = [remote_name, branch_name]                     if typeof callback    is "function"
    [remote, branch, callback] = ["origin", remote_name, branch_name] if typeof branch_name is "function"
    [remote, branch, callback] = ["origin", "master", remote_name]    if typeof remote_name is "function"

    @status (err, status) =>
      return callback err if err
      @git "stash", {}, ["save", "-u"], (err, stdout, stderr) =>
        return callback stderr if err
        @git "pull", {}, [remote, branch], (err, stdout, stderr) =>
          return callback stderr if err
          @git "push", {}, [remote, branch], (err, stdout, stderr) =>
            return callback stderr if err
            if not status?.clean
              @git "stash", {}, ["pop"], (err, stdout, stderr) =>
                return callback stderr if err
                return callback null
            else
              return callback null

  # Public: Pull the remotes from the master.
  #
  # Arguments: ([[remote_name, ]branch_name, ]callback)
  #
  # remote_name - String (optional).
  # branch_name - String.
  # callback - Receives `(stderr)`.
  #
  pull: (remote_name, branch_name, callback) ->

    # handle 'curried' arguments
    [remote, branch] = [remote_name, branch_name]                     if typeof callback    is "function"
    [remote, branch, callback] = ["origin", remote_name, branch_name] if typeof branch_name is "function"
    [remote, branch, callback] = ["origin", "master", remote_name]    if typeof remote_name is "function"

    @status (err, status) =>
      return callback err if err
      @git "pull", {}, [remote, branch], (err, stdout, stderr) =>
        return callback stderr if err
        return callback null

  # Internal: Parse the list of files from `git ls-files`
  #
  # Return Files[]
  parse_lsFiles: (text,options) ->
    files = []
    if _.has(options,'z')
      lines   = text.split "\0"
    else
    	lines   = text.split "\n"
    while lines.length
      line =  lines.shift().split(" ")
      files.push line
      while lines[0]? && !lines[0].length
        lines.shift()

    return files
