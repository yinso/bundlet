# adapted from shtylman's process package.

queue = []
draining = false

_drainQueue = () ->
  if draining
    return
  draining = true
  current = queue
  queue = []
  for item in current 
    item()
  draining = false

_NOOP = () ->

module.exports = 
  nextTick: (proc) ->
    queue.push proc
    if not draining
      setTimeout _drainQueue, 0
  title: 'browser'
  browser: true
  env: {}
  argv: []
  version: ''
  on: _NOOP
  addListener: _NOOP
  once: _NOOP
  off: _NOOP
  removeListener: _NOOP
  removeAllListeners: _NOOP
  emit: _NOOP
  binding: () ->
    throw {error: 'not_supported', name: 'process.binding'}
  cwd: () -> '/'
  chdir: (dir) -> 
    throw {error: 'not_supported', name: 'process.chdir'}
  umask: () -> 0

  