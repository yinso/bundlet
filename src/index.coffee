bundle = require './bundle'
loglet = require 'loglet'
funclet = require 'funclet'
path = require 'path'
fs = require 'fs'

run = (argv) ->
  bundle.bundle argv._[0], argv, (err, res) ->
    if err
      loglet.croak err
    else if argv.output 
      destPath = path.join argv.output, path.basename(argv._[0], path.extname(argv._[0])) + '.js'
      fs.writeFile destPath, res.join(''), (err) ->
        if err
          loglet.croak err
        else
          loglet.log 'saved to', destPath
    else
      try 
        for item in res
          loglet.log item
      catch e
        loglet.croak e
  
module.exports = 
  run: run
