# Public: Create a Status.
# 
# repo     - A Repo.
# callback - Receives `(err, status)`
# 
module.exports = S = (repo, callback) ->
  repo.git "status --porcelain", (err, stdout, stderr) ->
    status = new Status repo
    status.parse stdout
    callback err, status

S.Status = class Status
  constructor: (@repo) ->
  
  # Internal: Parse the status from stdout of a `git status` command.
  parse: (text) ->
    @files = {}
    @clean = text.length == 0
    for line in text.split("\n")
      if line.length == 0 
        continue
      file = line.substr 3
      type = line.substr 0,2
      @files[file] = { staged: (line[0] != " " and line[0] != "?" ) , tracked: line[0] != "?"  }
      if type != "??"
        @files[file].type = type.trim()
