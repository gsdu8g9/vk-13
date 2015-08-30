VK = require '../'

class VK.Error extends Error

  name: 'VK Error'

  constructor: (message) ->
    Error.captureStackTrace @, @constructor
    Object.defineProperty @, 'message',
      enumerable: false, value: message
