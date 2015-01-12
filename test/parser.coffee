parser = require '../src/parser'
assert = require 'assert'

describe 'parser test', () ->
  
  run = (stmt, expected) ->
    it "can parse #{stmt}", (done) ->
      try 
        actual = parser.parse stmt
        assert.deepEqual actual, expected
        done null
      catch e
        done e
  
  testCases = 
    [
      [
        "require('querystring');"
        [{require: 'querystring'}, ';']
      ]
      [
        "require( 'querystring' /* comment */);"
        [{require: 'querystring'}, ';']
      ]
      
      [
        """
        // this is a string that should be filtered
        // this is another string that should be filtered.
        /* require('xyz') */
        var x = 1
        """
        [
          {comment: '// this is a string that should be filtered\n'}
          {comment: '// this is another string that should be filtered.\n'}
          {comment: "/* require('xyz') */"}
          '\nvar x = 1'
        ]
      ]
      [ 
        """
        var x = /require('querystring')/g;
        """
        [
          'var x = '
          "/require('querystring')/g"
          ';'
        ]
      ]
      [
        """
        console.log(process.env);
        """
        [
          # {global: 'console', require: 'console'}
          #'.log('
          'console.log('
          {global: 'process', require: 'process'}
          '.env);'
        ]
      ]
    
    ]
  
  for [ stmt, expected ] in testCases
    run stmt, expected
  
  
