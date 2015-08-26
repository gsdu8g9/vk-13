module.exports = class LongPollUpdate

  cases =
    0:  [ 'message-', 'message_id', 0 ]
    1:  [ 'flags=', 'message_id', 'flags' ]
    2:  [ 'flags+', 'message_id', 'mask', 'user_id' ]
    3:  [ 'flags-', 'message_id', 'mask', 'user_id' ]
    4:  [ 'message+', 'message_id', 'flags', 'from_id',
          'timestamp', 'subject', 'text', 'attachments' ]
    6:  [ 'read<', 'peer_id', 'local_id' ]
    7:  [ 'read>', 'peer_id', 'local_id' ]
    8:  [ 'online', 'user_id', 'extra' ]
    9:  [ 'offline', 'user_id', 'flags' ]
    51: [ 'chat', 'chat_id', 'self' ]
    61: [ 'typing', 'user_id', 'flags' ]
    62: [ 'typing', 'user_id', 'chat_id' ]
    70: [ 'call', 'user_id', 'call_id' ]
    80: [ 'unread', 'count', 0 ]

  htmlpairs = [
    [ '\n', '<br>'   ]
    [ '<',  '&lt;'   ]
    [ '>',  '&gt;'   ]
    [ '"',  '&quot;' ]
    [ '&',  '&amp;'  ]
  ]

  htmldecode = (str) ->
    for pair in htmlpairs
      str = str
        .split pair[1]
        .join  pair[0]
    str

  constructor: (u) ->
    c = cases[(u = u[..]).shift()]
    u = new -> @[c[i+1]] = v for v, i in u; @
    u.text = htmldecode u.text if u.text
    u.attachments = (u.attachments[k + '_type'] + v \
      for own k, v of u.attachments when /h\d+$/.test k)
    @type = c[0]
    @data = u
