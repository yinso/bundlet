bundle = require './bundle'
loglet = require 'loglet'
funclet = require 'funclet'

run = (argv) ->
  bundle.bundle argv._[0], (err, res) ->
    if err
      loglet.croak err
    else
      try 
        for item in res
          loglet.log item
      catch e
        loglet.croak e
  
module.exports = 
  run: run
