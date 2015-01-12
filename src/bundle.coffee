#!/usr/bin/env coffee
#resolve = require 'resolve'
resolve = require 'browser-resolve'
loglet = require 'loglet'
path = require 'path'
fs = require 'graceful-fs'
funclet = require 'funclet'
parser = require './parser'
coffee = require 'coffee-script'
_ = require 'underscore'
builtin = require './builtin'

defaultOpts = { basedir: process.cwd(), extensions: ['.js', '.coffee']}

isExternal = (spec) ->
  spec.match /^[^\.\/]/

# the issue right now is that I don't have a way to merge in the shims...
# if I want to merge in the shims... 

# key -> needs to be something that's fixed - best is either absolute or relative path, or named spec.
# relPath -> 
# fullPath 

findPackageJson = (filePath, cb) ->
  helper = (filePath, cb) ->
    packageJson = path.join filePath, 'package.json'
    fs.stat packageJson, (err, stat) ->
      # file doesn't exist... 
      if err
        parentPath = path.dirname filePath
        if parentPath == filePath # we are at the root -> i.e. not exist. 
          cb err
        else
          helper parentPath, cb
      else if stat.isFile()
        fs.readFile packageJson, 'utf8', (err, data) ->
          if err 
            cb err
          else
            try 
              parsed = JSON.parse(data)
              cb null, filePath, parsed
            catch e
              cb e
      else # wrong file... 
        parentPath = path.dirname filePath
        if parentPath == filePath
          cb {error: 'package.json.not.found'}
        else
          helper parentPath, cb
  helper path.resolve(filePath), cb


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
    parser.parse compiled
  
  detect = (filePath, content) ->
    required = _.filter content, (item) -> item instanceof Object and item.require
    _.uniq _.map required, (item) -> 
      if item.global 
        if builtin.hasOwnProperty(item.global)# we want to map against the builtin... 
          builtin[item.global]
        else
          throw {error: 'unknown_global', global: item.global}
      else
        item.require
  
  normalizeName = (key, relPath) ->
    result = key.replace /[\/\.]/g, '_'
    "_Module_#{result}"
  
  parse = (filePath, key, relPath, cb) ->
    content = null
    funclet
      .bind(fs.readFile, filePath, 'utf8')
      .then (data, next) ->
        content = compile filePath, data
        next null, detect(filePath, content)
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
    #loglet.warn 'depends', spec
    tabLevel = options.tabLevel or 0
    tabMe = () ->
      ('  ' for i in [0...tabLevel]).join('')
    parent = options.parent or null
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
        else if filePath == spec and isExternal(filePath) # core-class unreferenced...
          next {error: 'core_module_unimplemented', module: spec, message: 'implement core module via browser field in package.json.'}
          #next null, normalize {key: spec, filePath: spec, depends: []}
        else if filePath.match /browser-resolve\/empty\.js$/ # this is skipped - ... # skipped files are not part of the processing
          next null, normalize {key: spec, filePath: filePath, depends: [], skipped: true, name: normalizeName(spec, filePath)}
        else 
          parse filePath, key, relPath, next
      .then (val, next) ->
        result = val
        sourceMap[result.key] = result
        next null, result.depends
      .thenMap (childSpec, next) ->
        opts = _.extend {}, options, {basedir: path.dirname(filePath), tabLevel: tabLevel + 1, parent: spec}
        depends childSpec, opts, (err, mod) ->
          if err 
            next err
          else
            next null, {spec: childSpec, module: mod}
      .catch(cb)
      .done (required) -> 
        #  key: result.key
        #  relPath: result.relPath
        #  filePath: result.filePath
        #  name: result.name
        result.depends = required
        cb null, result
  
  funclet
    .start (next) ->
      findPackageJson spec, next
    .catch (err) ->
      cb err
    .done (packagePath, data) ->
      options.shims = _.extend {}, options.shims or {}, data.bundlet?.shims or {}
      options.modules = builtin
      depends spec, options, cb

topsort = (mod, result = []) ->
  #loglet.warn 'topsort', mod.name, mod.key, mod.relPath, (child.spec for child in mod.depends)
  for {spec, module} in mod.depends 
    if not _.contains result, module 
      topsort module, result
  result.push mod
  result

transform = (mod) ->
  #loglet.warn 'transform', mod.name, mod.key, mod.relPath
  if mod.external
    """
    // module: #{mod.key} 
    var #{mod.name} = #{mod.external};
    """
  else if mod.content
    #parsed = parser.parse mod.content
    # what do we get what we parse these things?
    buffer = []
    for item in mod.content 
      if typeof(item) == 'string'
        buffer.push item
      else if item.global
        buffer.push item.global
      else if item.require
        mapped = _.find mod.depends, (dep) -> dep.spec == item.require
        if mapped 
          buffer.push mapped.module.name
        else
          throw {error: 'unknown_mapped_spec', key: mod.key, relPath: mod.relPath, spec: item.require, depends: mod.depends}
      else if item.comment
        buffer.push item.comment
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

