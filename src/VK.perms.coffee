VK = require '../'

names = 'notify,friends,photos,audio,video,offers,questions,'  +
        'pages,menu,,status,notes,messages,wall,,ads,offline,' +
        'docs,groups,notifications,stats,,email,adsweb'

VK.perms = {}
VK.perms[x] = 1<<i for x, i in names.split ',' when x
VK.perms.all = -1 + Object.keys VK.perms
  .map (key) -> VK.perms[key]
  .reduce (a, b) -> a | b
