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
# depth      - The specified number of revisions of shallow clone
# callback   - Receives `(err, repo)`.
#
Git.clone = (repository, path, depth = 0, branch = null, callback) ->
  if typeof branch is 'function'
    callback = branch
    branch = null
  if typeof depth is 'function'
    callback = depth
    depth = 0
  bash = "git clone \"#{repository}\" \"#{path}\""

  if branch isnt null and typeof branch is 'string'
    bash += " --branch \"#{branch}\""
  if depth isnt 0 and typeof depth is 'number'
    bash += " --depth \"#{depth}\""

  exec bash, (err, stdout, stderr) ->
    return callback err if err
    return callback err, (new Repo path, false, { maxBuffer: Git.maxBuffer })
