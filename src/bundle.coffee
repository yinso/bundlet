#!/usr/bin/env coffee
#resolve = require 'resolve'
resolve = require 'browser-resolve'
loglet = require 'loglet'
path = require 'path'
fs = require 'fs'
funclet = require 'funclet'
detective = require 'detective' # can replace this...
nocomment = require './nocomment'
coffee = require 'coffee-script'
findPackageJson = require 'witwip'
_ = require 'underscore'

defaultOpts = { basedir: process.cwd(), extensions: ['.js', '.coffee']}

isExternal = (spec) ->
  spec.match /^[^\.\/]/

# the issue right now is that I don't have a way to merge in the shims...
# if I want to merge in the shims... 

# key -> needs to be something that's fixed - best is either absolute or relative path, or named spec.
# relPath -> 
# fullPath 


dependsRecur = (spec, options, cb) ->
  if arguments.length == 2
    cb = options
    options = defaultOpts
  else
    options = _.extend {}, defaultOpts, options
  
  options.rootdir ||= options.basedir
  
  sourceMap = {}
  
  normalize = (result) ->
    if options.shims.hasOwnProperty(result.key)
      # shim overwrites the results 
      res = _.extend {}, result, options.shims[result.key]
      res
    else
      result
  
  compile = (filePath, data) ->
    compiled = 
      if path.extname(filePath) == '.coffee'
        coffee.compile data
      else
        data
    nocomment.parse compiled
  
  detect = (content) ->
    required = _.filter content, (item) -> item instanceof Object and item.require
    _.map required, (item) -> item.require
  
  normalizeName = (key, relPath) ->
    result = key.replace /[\/\.]/g, '_'
    "_Module_#{result}"
  
  parse = (filePath, key, relPath, cb) ->
    content = null
    funclet
      .bind(fs.readFile, filePath, 'utf8')
      .then (data, next) ->
        content = compile filePath, data
        next null, detect(content)
      .catch(cb)
      .done (required) ->
        result = normalize
          key: key
          relPath: relPath
          depends: required
          filePath: filePath
          name: normalizeName key, relPath
          content: content
        cb null, result
  
  depends = (spec, options, cb) ->
    if sourceMap.hasOwnProperty(spec)
      return cb null, sourceMap[spec]
    filePath = null
    relPath = null
    key = null
    result = null 
    funclet
      .start (next) ->
        resolve spec, options, (err, res) ->
          next err, res
      .then (val, next) ->
        filePath = val
        relPath = './' + path.relative(options.rootdir, filePath)
        key = if isExternal(spec) then spec else relPath
        if sourceMap.hasOwnProperty(key)
          cb null, sourceMap[key]
        else if filePath == spec # core-class unreferenced...
          next {error: 'core_module_unimplemented', module: spec, message: 'implement core module via browser field in package.json.'}
          #next null, normalize {key: spec, filePath: spec, depends: []}
        else if filePath.match /browser-resolve\/empty\.js$/ # this is skipped - ... # skipped files are not part of the processing
          next null, normalize {key: spec, filePath: filePath, depends: [], skipped: true, name: normalizeName(spec, filePath)}
        else 
          parse filePath, key, relPath, next
      .then (val, next) ->
        result = val
        next null, result.depends
      .thenMap (spec, next) ->
        opts = _.extend {}, options, {basedir: path.dirname(filePath)}
        depends spec, opts, (err, mod) ->
          if err 
            next err
          else
            next null, {spec: spec, module: mod}
      .catch(cb)
      .done (required) -> 
        result.depends = required
        sourceMap[result.key] = result
        cb null, result
  
  funclet
    .start (next) ->
      findPackageJson spec, next
    .catch (err) ->
      cb err
    .done (packagePath, data) ->
      options.shims = _.extend {}, options.shims or {}, data.bundlet?.shims or {}
      depends spec, options, cb

topsort = (mod, result = []) ->
  for {spec, module} in mod.depends 
    if not _.contains result, module 
      topsort module, result
  result.push mod
  result

transform = (mod) ->
  if mod.external
    """
    // module: #{mod.key} 
    var #{mod.name} = #{mod.external};
    """
  else if mod.content
    #parsed = nocomment.parse mod.content
    # what do we get what we parse these things?
    buffer = []
    for item in mod.content 
      if typeof(item) == 'string'
        buffer.push item
      else if item.require
        mapped = _.find mod.depends, (dep) -> dep.spec == item.require
        if mapped 
          buffer.push mapped.module.name
        else
          throw {error: 'unknown_mapped_spec', key: mod.key, relPath: mod.relPath, spec: item.require}
      else
        throw {error: 'unknown_parsed_object', object: item}
    content = buffer.join ''
    """
    // module: #{mod.key}
    var #{mod.name} = (function() {
      var exports = {};
      var module = { exports: exports };
      (function (){
        #{content}
      })();
      return #{if mod.exports then mod.exports else 'module.exports'};
    })();
    """
  else
    throw {error: 'invalid_module_structure', module: mod}

bundle = (spec, cb) ->
  dependsRecur spec, (err, res) ->
    if err
      cb err
    else
      try 
        cb null, (transform(mod) for mod in topsort(res))
      catch e
        cb e

module.exports = 
  bundle: bundle

