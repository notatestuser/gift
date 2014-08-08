fs     = require 'fs'
{exec, spawn} = require 'child_process'

module.exports = Git = (git_dir, dot_git) ->
  dot_git ||= "#{git_dir}/.git"

  git = (command, options, args, callback) ->
    [callback, args]    = [args, callback] if !callback
    [callback, options] = [options, callback] if !callback
    options ?= {}
    options  = options_to_argv options
    args    ?= []
    args     = args.split " " if typeof args == 'string'
    args     = [ command ].concat options, args

    stdout   = ''
    stderr   = ''
    proc     = spawn Git.bin, args, {cwd: git_dir}
    proc.stdout.on 'data', ( buffer ) ->
      stdout += buffer.toString 'binary'
    proc.stderr.on 'data', ( buffer ) ->
      stderr += buffer.toString 'binary'
    proc.on 'error', (err) ->
      callback err, stdout, stderr
    proc.on 'exit', () ->
      callback null, stdout, stderr

  # Public: Passthrough for raw git commands
  #
  git.cmd  = (command, options, args, callback) ->
    git command, options, args, callback

  # Public: stream results of git command
  #
  # This is used for large files that you'd need to stream.
  #
  # returns [outstream, errstream]
  #
  git.streamCmd = (command, options, args) ->
    options ?= {}
    options  = options_to_argv options
    args    ?= []
    allargs = [command].concat(options).concat(args)
    process  = spawn Git.bin, allargs, {cwd: git_dir, encoding: 'binary'}
    return [process.stdout, process.stderr]

  # Public: Get a list of the remote names.
  #
  # callback - Receives `(err, names)`.
  #
  git.list_remotes = (callback) ->
    fs.readdir "#{dot_git}/refs/remotes", (err, files) ->
      callback err, (files || [])


  # Public: Get the ref data string.
  #
  # type     - Such as `remote` or `tag`.
  # callback - Receives `(err, stdout)`.
  #
  git.refs = (type, options, callback) ->
    [callback, options] = [options, callback] if !callback
    prefix              = "refs/#{type}s/"

    git "show-ref", (err, text) ->
      # ignore error code 1: means no match
      err = null if err?.code is 1
      matches = []
      for line in (text || "").split("\n")
        continue if !line
        [id, name] = line.split(' ')
        if name.substr(0, prefix.length) == prefix
          matches.push "#{name.substr(prefix.length)} #{id}"
      return callback err, matches.join("\n")

  return git


# Public: The `git` command.
Git.bin = "git"



# Internal: Transform an Object into command line options.
#
# Returns an Array of String option arguments.
Git.options_to_argv = options_to_argv = (options) ->
  argv = []
  for key, val of options
    if key.length == 1
      if val == true
        argv.push "-#{key}"
      else if val == false
        # ignore
      else
        argv.push "-#{key}"
        argv.push val
    else
      if val == true
        argv.push "--#{key}"
      else if val == false
        # ignore
      else
        argv.push "--#{key}=#{val}"
  return argv
