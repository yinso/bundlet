// Generated by CoffeeScript 1.4.0
(function() {
  var bundle, coffee, defaultOpts, dependsRecur, detective, findPackageJson, fs, funclet, isExternal, loglet, nocomment, path, resolve, topsort, transform, _;

  resolve = require('browser-resolve');

  loglet = require('loglet');

  path = require('path');

  fs = require('fs');

  funclet = require('funclet');

  detective = require('detective');

  nocomment = require('./nocomment');

  coffee = require('coffee-script');

  findPackageJson = require('witwip');

  _ = require('underscore');

  defaultOpts = {
    basedir: process.cwd(),
    extensions: ['.js', '.coffee']
  };

  isExternal = function(spec) {
    return spec.match(/^[^\.\/]/);
  };

  dependsRecur = function(spec, options, cb) {
    var compile, depends, detect, normalize, normalizeName, parse, sourceMap;
    if (arguments.length === 2) {
      cb = options;
      options = defaultOpts;
    } else {
      options = _.extend({}, defaultOpts, options);
    }
    options.rootdir || (options.rootdir = options.basedir);
    sourceMap = {};
    normalize = function(result) {
      var res;
      if (options.shims.hasOwnProperty(result.key)) {
        res = _.extend({}, result, options.shims[result.key]);
        return res;
      } else {
        return result;
      }
    };
    compile = function(filePath, data) {
      var compiled;
      compiled = path.extname(filePath) === '.coffee' ? coffee.compile(data) : data;
      return nocomment.parse(compiled);
    };
    detect = function(content) {
      var required;
      required = _.filter(content, function(item) {
        return item instanceof Object && item.require;
      });
      return _.map(required, function(item) {
        return item.require;
      });
    };
    normalizeName = function(key, relPath) {
      var result;
      result = key.replace(/[\/\.]/g, '_');
      return "_Module_" + result;
    };
    parse = function(filePath, key, relPath, cb) {
      var content;
      content = null;
      return funclet.bind(fs.readFile, filePath, 'utf8').then(function(data, next) {
        content = compile(filePath, data);
        return next(null, detect(content));
      })["catch"](cb).done(function(required) {
        var result;
        result = normalize({
          key: key,
          relPath: relPath,
          depends: required,
          filePath: filePath,
          name: normalizeName(key, relPath),
          content: content
        });
        return cb(null, result);
      });
    };
    depends = function(spec, options, cb) {
      var filePath, key, relPath, result;
      if (sourceMap.hasOwnProperty(spec)) {
        return cb(null, sourceMap[spec]);
      }
      filePath = null;
      relPath = null;
      key = null;
      result = null;
      return funclet.start(function(next) {
        return resolve(spec, options, function(err, res) {
          return next(err, res);
        });
      }).then(function(val, next) {
        filePath = val;
        relPath = './' + path.relative(options.rootdir, filePath);
        key = isExternal(spec) ? spec : relPath;
        if (sourceMap.hasOwnProperty(key)) {
          return cb(null, sourceMap[key]);
        } else if (filePath === spec) {
          return next({
            error: 'core_module_unimplemented',
            module: spec,
            message: 'implement core module via browser field in package.json.'
          });
        } else if (filePath.match(/browser-resolve\/empty\.js$/)) {
          return next(null, normalize({
            key: spec,
            filePath: filePath,
            depends: [],
            skipped: true,
            name: normalizeName(spec, filePath)
          }));
        } else {
          return parse(filePath, key, relPath, next);
        }
      }).then(function(val, next) {
        result = val;
        return next(null, result.depends);
      }).thenMap(function(spec, next) {
        var opts;
        opts = _.extend({}, options, {
          basedir: path.dirname(filePath)
        });
        return depends(spec, opts, function(err, mod) {
          if (err) {
            return next(err);
          } else {
            return next(null, {
              spec: spec,
              module: mod
            });
          }
        });
      })["catch"](cb).done(function(required) {
        result.depends = required;
        sourceMap[result.key] = result;
        return cb(null, result);
      });
    };
    return funclet.start(function(next) {
      return findPackageJson(spec, next);
    })["catch"](function(err) {
      return cb(err);
    }).done(function(packagePath, data) {
      var _ref;
      options.shims = _.extend({}, options.shims || {}, ((_ref = data.bundlet) != null ? _ref.shims : void 0) || {});
      return depends(spec, options, cb);
    });
  };

  topsort = function(mod, result) {
    var module, spec, _i, _len, _ref, _ref1;
    if (result == null) {
      result = [];
    }
    _ref = mod.depends;
    for (_i = 0, _len = _ref.length; _i < _len; _i++) {
      _ref1 = _ref[_i], spec = _ref1.spec, module = _ref1.module;
      if (!_.contains(result, module)) {
        topsort(module, result);
      }
    }
    result.push(mod);
    return result;
  };

  transform = function(mod) {
    var buffer, content, item, mapped, _i, _len, _ref;
    if (mod.external) {
      return "// module: " + mod.key + " \nvar " + mod.name + " = " + mod.external + ";";
    } else if (mod.content) {
      buffer = [];
      _ref = mod.content;
      for (_i = 0, _len = _ref.length; _i < _len; _i++) {
        item = _ref[_i];
        if (typeof item === 'string') {
          buffer.push(item);
        } else if (item.require) {
          mapped = _.find(mod.depends, function(dep) {
            return dep.spec === item.require;
          });
          if (mapped) {
            buffer.push(mapped.module.name);
          } else {
            throw {
              error: 'unknown_mapped_spec',
              key: mod.key,
              relPath: mod.relPath,
              spec: item.require
            };
          }
        } else {
          throw {
            error: 'unknown_parsed_object',
            object: item
          };
        }
      }
      content = buffer.join('');
      return "// module: " + mod.key + "\nvar " + mod.name + " = (function() {\n  var exports = {};\n  var module = { exports: exports };\n  (function (){\n    " + content + "\n  })();\n  return " + (mod.exports ? mod.exports : 'module.exports') + ";\n})();";
    } else {
      throw {
        error: 'invalid_module_structure',
        module: mod
      };
    }
  };

  bundle = function(spec, cb) {
    return dependsRecur(spec, function(err, res) {
      var mod;
      if (err) {
        return cb(err);
      } else {
        try {
          return cb(null, (function() {
            var _i, _len, _ref, _results;
            _ref = topsort(res);
            _results = [];
            for (_i = 0, _len = _ref.length; _i < _len; _i++) {
              mod = _ref[_i];
              _results.push(transform(mod));
            }
            return _results;
          })());
        } catch (e) {
          return cb(e);
        }
      }
    });
  };

  module.exports = {
    bundle: bundle
  };

}).call(this);