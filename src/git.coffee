fs     = require 'fs'
{exec} = require 'child_process'

module.exports = Git = (git_dir, dot_git) ->
  dot_git ||= "#{git_dir}/.git"

  git = (command, options, args, callback) ->
    [callback, args]    = [args, callback] if !callback
    [callback, options] = [options, callback] if !callback
    options ?= {}
    options  = options_to_argv options
    options  = options.join " "
    args    ?= []
    args     = args.join " " if args instanceof Array
    bash     = "#{Git.bin} #{command} #{options} #{args}"
    exec bash, {cwd: git_dir, maxBuffer: 5000*1024}, callback
    return bash


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
