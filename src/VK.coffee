Promise = require 'bluebird'
request = require 'request'
qstring = require 'querystring'
events  = require 'events'

request = request.defaults followAllRedirects: true
Request = Promise.promisify request

VK = exports
VK.LongPollUpdate = require './LongPollUpdate'


perms = 'notify,friends,photos,audio,video,offers,questions,'  +
        'pages,menu,,status,notes,messages,wall,,ads,offline,' +
        'docs,groups,notifications,stats,,email,adsweb'

VK.perms = {}
VK.perms[x] = 1<<i for x, i in perms.split ',' when x
VK.perms.all = -1 + Object.keys VK.perms
  .map (key) -> VK.perms[key]
  .reduce (a, b) -> a | b


VK.Android = [ 2274003, 'hHbZxrka2uZ6jB1inYsH' ]
VK.WPhone  = [ 3502557, 'PEObAuQi6KloPM4T30DV' ]
VK.iPhone  = [ 3140623, 'VeWdmVclDCtn6ihuP1nt' ]
VK.iPad    = [ 3682744, 'mY6CDUswIVdJLCD3j15n' ]


class VK.Error extends Error

  name: 'VK Error'

  constructor: (message) ->
    Error.captureStackTrace @, @constructor
    Object.defineProperty @, 'message',
      enumerable: false, value: message


class VK.APIError extends VK.Error

  name: 'VK API Error'

  constructor: (json) ->
    super json.error_msg
    @code = json.error_code
    @args = {}
    @args[p.key] = p.value for p in json.request_params


class VK.API extends events.EventEmitter

  v:     5.37
  app:   VK.Android
  scope: VK.perms.all
  delay: 350

  constructor: (app, scope, v) ->
    @v     = v if v?
    @app   = app if app?
    @scope = scope if scope?
    @last  = Date.now() - @delay
    @parseScope()

    if typeof @app is 'object'
      [ @app, @secret ] = @app

    if typeof @app is 'string'
      @session = access_token: @app

  parseScope: ->
    try
      scope = @scope.toLowerCase().split ','
      for x, i in scope
        throw null if x not of VK.perms
        scope[i] = VK.perms[x]
      @scope = scope.reduce (a, b) -> a | b

  directAuth: ->
    console.error 'Logging in (direct auth)'
    Request
      json: true, method: 'POST'
      url: 'https://oauth.vk.com/token',
      form:
        grant_type: 'password', client_secret: @secret
        client_id: @app, scope: @scope, v: @v
        username: @username, password: @password

    .spread (res, json) ->
      if json.error
        throw new VK.Error json.error_description
      json

  clientAuth: ->
    console.error 'Going to login page'
    Request
      jar: jar = request.jar()
      url: 'https://m.vk.com/'

    .spread (res, body) =>
      console.error 'Logging in'
      Request
        jar: jar, method: 'POST'
        url: /action="(.*?)"/.exec(body)[1]
        form: email: @username, pass: @password

    .spread (res, body) =>
      if /\/captcha[^"]+/.exec body
        throw new VK.Error 'Captcha needed'

      cookies = jar.getCookies 'https://login.vk.com'
      if 'l' not in (cookies.map (cookie) -> cookie.key)
        throw new VK.Error 'Cannot login using given username/password'

      console.error 'Getting access token'
      Request
        url: 'https://oauth.vk.com/authorize'
        jar: jar, qs:
          display: 'mobile', response_type: 'token'
          client_id: @app, scope: @scope, v: @v

    .spread (res, body) ->
      return [res, body] if res.request.uri.hash

      console.error 'Confirming permissions'
      Request
        jar: jar, url: /action="(.*?)"/.exec(body)[1]

    .spread (res, body) ->
      qstring.parse res.request.uri.hash[1..]

  login: (username, password, callback) ->
    @username = username if username?
    @password = password if password?

    new Promise (done, fail) =>
      if @username and @password
        done if @secret then @directAuth() else @clientAuth()
      else
        fail new VK.Error 'No username/password given'

    .then (session) => @session = session
    .nodeify callback

  api: (method, args, callback) ->
    return @login null, null, callback unless @session

    qs = v: @v, access_token: @session.access_token
    qs[k] = v for own k, v of args if args

    delay = Math.max 0, @last + @delay - Date.now()
    @last = Date.now() + delay

    Promise.delay delay

    .then ->
      Request
        url: 'https://api.vk.com/method/' + method
        json: true, qs: qs

    .spread (res, json) ->
      throw new VK.APIError json.error if json.error
      json.response

    .nodeify callback

  listen: (wait = 60) ->
    server = null

    do fn = =>
      if not server
        server = @api 'messages.getLongPollServer'

      server.then (s) =>
        Request
          url: 'http://' + s.server
          json: true, qs:
            act: 'a_check', wait: wait
            mode: 2, key: s.key, ts: s.ts

        .spread (r, json) =>
          if json.failed
            server = null
            throw new Error 'Long polling error'

          for u in json.updates
            u = new VK.LongPollUpdate u
            @emit u.type, u.data

          s.ts = json.ts

      .catch (e) => @emit 'error', e
      .then fn
      return
