VK = require '../'

class VK.APIError extends VK.Error

  name: 'VK API Error'

  constructor: (json) ->
    super json.error_msg
    @code = json.error_code
    @args = {}
    @args[p.key] = p.value for p in json.request_params
