names = 'notify,friends,photos,audio,video,offers,questions,'  +
        'pages,menu,,status,notes,messages,wall,,ads,offline,' +
        'docs,groups,notifications,stats,,email,adsweb'

perms = module.exports = {}
perms[x] = 1<<i for x, i in names.split ',' when x
perms.all = -1 + Object.keys perms
  .map (key) -> perms[key]
  .reduce (a, b) -> a | b
