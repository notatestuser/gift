(function() {
  var BEGIN_STAGED, BEGIN_UNSTAGED, BEGIN_UNTRACKED, FILE, S, Status, TYPES;

  module.exports = S = function(repo, callback) {
    return repo.git("status", function(err, stdout, stderr) {
      var status;
      status = new Status(repo);
      status.parse(stdout);
      return callback(err, status);
    });
  };

  BEGIN_STAGED = ["# Changes to be committed:"];

  BEGIN_UNSTAGED = ["# Changed but not updated:", "# Changes not staged for commit:"];

  BEGIN_UNTRACKED = ["# Untracked files:"];

  FILE = /^#\s+([^\s]+)[:]\s+(.+)$/;

  TYPES = {
    added: "A",
    modified: "M",
    deleted: "D"
  };

  S.Status = Status = (function() {

    function Status(repo) {
      this.repo = repo;
    }

    Status.prototype.parse = function(text) {
      var data, file, line, match, state, _i, _len, _ref;
      this.files = {};
      this.clean = true;
      state = null;
      _ref = text.split("\n");
      for (_i = 0, _len = _ref.length; _i < _len; _i++) {
        line = _ref[_i];
        if (~BEGIN_STAGED.indexOf(line)) {
          state = "staged";
          this.clean = false;
        } else if (~BEGIN_UNSTAGED.indexOf(line)) {
          state = "unstaged";
          this.clean = false;
        } else if (~BEGIN_UNTRACKED.indexOf(line)) {
          state = "untracked";
          this.clean = false;
        } else if (state && (match = FILE.exec(line))) {
          file = match[2];
          data = (function() {
            switch (state) {
              case "staged":
                return {
                  staged: true,
                  tracked: true
                };
              case "unstaged":
                return {
                  staged: false,
                  tracked: true
                };
            }
          })();
          data.type = TYPES[match[1]];
          this.files[file] = data;
        } else if (state === "untracked" && (match = /^#\s+([^\s]+)$/.exec(line))) {
          file = match[1];
          this.files[file] = {
            tracked: false
          };
        }
      }
    };

    return Status;

  })();

}).call(this);