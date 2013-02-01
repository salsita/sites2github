spawn = (require 'child_process').spawn
q = require 'q'
url = require 'url'
path = require 'path'
fs = require 'q-io/fs'

class exports.Git
  rootPath: null
  initialized: false

  constructor: (@remoteURL) ->
    urlPath = path.basename (url.parse @remoteURL).path
    @rootPath = path.join process.cwd(), urlPath.substr 0, urlPath.length-4 # Remove .git suffix

  _spawnCommand = (command, args = []) ->
    deferred = q.defer()
    # Since we might not be in the repository's working directory, we need these options.
    defaults =
    [
      "--git-dir=#{@rootPath}/.git"
      "--work-tree=#{@rootPath}"
    ]
    options = if @initialized then defaults else []
    options.push command
    process = spawn 'git', options.concat(args)
    process.stdout.on 'data', (data) ->
      console.log('ps stdout: ' + data);
    process.stderr.on 'data', (data) ->
      console.log('ps stderr: ' + data);
    process.on 'exit', (code) =>
      if code == 0
        deferred.resolve code
      else
        deferred.reject "Spawn failed with exit code #{code}"
    return deferred.promise

  exists: ->
    deferred = q.defer()
    fs.exists("#{@rootPath}/.git")
    .then (exists) =>
      @initialized = exists
      deferred.resolve exists
    return deferred.promise

  clone: () ->
    deferred = q.defer()
    _spawnCommand.call(this, 'clone', @remoteURL)
    .then () =>
      @initialized = true
      deferred.resolve()
    .done()
    return deferred.promise

  add: (filePath) ->
    _spawnCommand.call this, 'add', filePath

  commit: (message) ->
    _spawnCommand.call this, 'commit', [ '-m', message ]

  push: () ->
    _spawnCommand.call this, 'push'
