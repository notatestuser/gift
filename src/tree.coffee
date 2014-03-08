_         = require 'underscore'
Blob      = require './blob'
Submodule = require './submodule'

module.exports = class Tree
  # repo    - A Repo.
  # options - An Object with properties "id", "name", and "mode";
  #           or just a String id.
  constructor: (@repo, options) ->
    if _.isString options
      @id = options
    else
      {@id, @name, @mode} = options
  
  
  # Public: Get the children of the tree.
  # 
  # callback - Receives `(err, children)`, where children is a list
  #            of Trees, Blobs, and Submodules.
  # 
  contents: (callback) ->
    return callback null, @_contents if @_contents
    @repo.git "ls-tree", {}, @id
    , (err, stdout, stderr) =>
      return callback err if err
      @_contents = []
      for line in stdout.split("\n")
        @_contents.push @content_from_string(line) if line
      return callback null, @_contents
  
  
  # Public: Get the child blobs.
  # 
  # callback - Receives `(err, blobs)`.
  # 
  blobs: (callback) ->
    @contents (err, children) ->
      return callback err if err
      return callback null, _.filter children, (child) ->
        child instanceof Blob
  
  
  # Public: Get the child blobs.
  # 
  # callback - Receives `(err, trees)`.
  # 
  trees: (callback) ->
    @contents (err, children) ->
      return callback err if err
      return callback null, _.filter children, (child) ->
        child instanceof Tree
  
  
  # Public: Find the named object in this tree's contents.
  # 
  # callback - Receives `(err, obj)` where obj is Tree, Blob, or null
  #            if not found.
  # 
  find: (file, callback) ->
    if /\//.test file
      console.log "looking for tree"
      path_components = file.split "/"
      dir = path_components[0]
      rest = path_components.slice(1, path_components.length).join("/")
      console.log dir, rest
      @trees (err, _trees) =>
        console.log _trees.map (e) -> e.name
        for tree in _trees
          console.log tree.name == dir
          return tree.find rest, callback if tree.name == dir
        return callback null, null
    else
      console.log "looking for blob"
      @contents (err, children) ->
        return callback err if err
        for child in children
          if child.name == file
            return callback null, child
        return callback null, null
  
  
  # Internal: Parse a Blob or Tree from the line.
  # 
  # line - String
  # 
  # Examples
  # 
  #   tree.content_from_string "100644 blob e4ff69dd8f19d770e9731b4bc424ccb695f0b5ad    README.md"
  #   # => #<Blob >
  # 
  # Returns Blob, Tree or Submodule.
  content_from_string: (line) ->
    [mode, type, id, name] = line.split /[\t ]+/, 4
    switch type
      when "tree"
        new Tree @repo, {id, name, mode}
      when "blob"
        new Blob @repo, {id, name, mode}
      when "link"
        new Blob @repo, {id, name, mode}
      when "commit"
        new Submodule @repo, {id, name, mode}
      else
        throw new Error "Invalid object type: '#{type}'"
  
  # Public: Get a String representation of the Tree.
  # 
  # Returns String.
  toString: ->
    "#<Tree '#{@id}'>"
