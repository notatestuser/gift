{exec} = require 'child_process'
Repo   = require './repo'

# Public: Create a Repo from the given path.
#
# Returns Repo.
module.exports = Git = (path, bare=false, git_options={
  maxBuffer: Git.maxBuffer
}) -> return new Repo path, bare, git_options

# Public: maxBuffer size for git commands
Git.maxBuffer = 5000 * 1024

# Public: Initialize a git repository.
#
# path     - The directory to run `git init .` in.
# bare     - Create a bare repository when true.
# callback - Receives `(err, repo)`.
#
Git.init = (path, bare, callback) ->
  [bare, callback] = [callback, bare] if !callback
  if bare
    bash = "git init --bare ."
  else
    bash = "git init ."
  exec bash, {cwd: path}
  , (err, stdout, stderr) ->
    return callback err if err
    return callback err, (new Repo path, bare, { maxBuffer: Git.maxBuffer })

# Public: Clone a git repository.
#
# repository - The repository to clone from.
# path       - The directory to clone into.
# callback   - Receives `(err, repo)`.
#
Git.clone = (repository, path, callback) ->
  bash = "git clone #{repository} #{path}"
  exec bash, (err, stdout, stderr) ->
    return callback err if err
    return callback err, (new Repo path, false, { maxBuffer: Git.maxBuffer })

# Public: Pull a git repository.
#
# remote     - The remote to pull from.
# branch     - The branch to pull from.
# path       - The directory to pull into.
# callback   - Receives `(err, repo)`.
#
Git.pull = (remote = '', branch = '', path = '', callback) ->
  if (remote == '' || branch == '')
    if (path == '')
      bash = "git pull"
    else
      bash = "git -C #{path} pull"
  else
    if (path == '')
      bash = "git pull #{remote} #{branch}"
    else
      bash = "git -C #{path} pull #{remote} #{branch}"
  exec bash, (err, stdout, stderr) ->
    return callback err if err
    return callback err, (new Repo path)
