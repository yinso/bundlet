// Generated by CoffeeScript 1.4.0
(function() {
  var bundle, funclet, loglet, run;

  bundle = require('./bundle');

  loglet = require('loglet');

  funclet = require('funclet');

  run = function(argv) {
    return bundle.bundle(argv._[0], function(err, res) {
      var item, _i, _len, _results;
      if (err) {
        return loglet.croak(err);
      } else {
        try {
          _results = [];
          for (_i = 0, _len = res.length; _i < _len; _i++) {
            item = res[_i];
            _results.push(loglet.log(item));
          }
          return _results;
        } catch (e) {
          return loglet.croak(e);
        }
      }
    });
  };

  module.exports = {
    run: run
  };

}).call(this);