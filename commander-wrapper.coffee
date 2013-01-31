q = require 'q'
commander = require 'commander'

wrapCommander = (method) ->
  (commanderArguments...) ->
    deferred = q.defer()
    commanderArguments.push (response) -> deferred.resolve response
    commander[method].apply commander, commanderArguments
    deferred.promise


commanderMethods = [
  'prompt'
  'choose'
  'confirm'
  'password'
]

exports[method] = wrapCommander method for method in commanderMethods
