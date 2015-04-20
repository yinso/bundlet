#!/usr/bin/env node
var yargs = require('yargs')
  .demand('output')
  .alias('o', 'output')
  .alias('d', 'depends')
  .demand(1);
var bundlet = require('../lib/');

bundlet.run(yargs.argv);

