#!/usr/bin/env node
var yargs = require('yargs')
  .demand(1);
var bundlet = require('../lib/');

bundlet.run(yargs.argv);

