VK = require '../'

class VK.LongPollError extends VK.Error

  name: 'VK Long Poll Error'

  constructor: (json) ->
    super json.failed ? 'Something went wrong'
    @code = json.failed ? 4
