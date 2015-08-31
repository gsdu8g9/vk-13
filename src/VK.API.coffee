VK      = require '../'
Promise = require 'bluebird'
request = require 'request'
qstring = require 'querystring'
events  = require 'events'

request = request.defaults followAllRedirects: true
Request = Promise.promisify request

class VK.API extends events.EventEmitter

  v:     5.37
  app:   VK.apps.Android
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

    Promise.try =>
      unless @username and @password
        throw new VK.Error 'No username/password given'

      if @secret then @directAuth() else @clientAuth()

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

  poll: (wait = 60, callback) ->
    @longPollServer = @longPollServer or
      @api 'messages.getLongPollServer'

    @longPollServer.then (server) ->
      Request
        url: 'http://' + server.server
        timeout: (wait + 1) * 1000
        json: true, qs:
          act: 'a_check', wait: wait
          mode: 2, key: server.key, ts: server.ts

      .spread (r, json) ->
        throw new Error if not json.updates?
        server.ts = json.ts
        json.updates

      .map (update) ->
        new VK.LongPollUpdate update

    .catch (e) =>
      @longPollServer = null
      throw e

    .nodeify callback

  listen: (wait) ->
    do fn = =>
      @poll wait
      .each (u) => @emit u.type, u.data
      .then fn, fn
    return
