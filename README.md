VK API module for Node.js
=========================

Installation and building
-------------------------

```sh
$ git clone https://github.com/thepheer/vk.git && cd vk
$ npm install
$ npm run build
```

Usage example
-------------

##### JavaScript:

```js
var VK = require('./vk/');
var vk = new VK.API(/* APP_ID, SCOPE, API_VERSION */);

vk.login('username or phone number', 'password')

.then(function () {
  // logged in
  // let's make some API call
  return vk.api('users.get');
})

.then(function (users) {
  var user = users[0];
  var name = user.first_name + ' ' + user.last_name;
  console.log(name); // whoa, we got your name!

  // let's do something more complex
  // get some friends to start
  return vk.api('friends.get', { count: 5 });
})

.then(function (friends) {
  // and here they are
  // print them out
  console.log(friends);

  // there is no need to stack
  // callbacks like egyptian pyramids

  // for get first photo of each friend
  // we pass them to the .map function
  return friends.items;
})

.map(function (friend) {
  // and request photos from 'profile' album
  return vk.api('photos.get', {
    owner_id: friend,
    album_id: 'profile',
    count: 1, rev: 1, photo_sizes: 1
  })
  .then(function (response) {
    // we want only the first
    var photo = response.items[0];

    // and the largest one
    var largestPhotoURL = photo
      .sizes[photo.sizes.length - 1].src;

    // mapping will take a while
    // we don't want to look at
    // empty console window, right?
    console.log('Done for id:', friend);

    return largestPhotoURL;
  });
})

// check out what we got
.then(console.log)

// you may have noticed that
// there is no error handling at all
// because it's the final part of the example

// look how easy we can handle all the errors
// that may happen in any part of the code

// this will catch any API errors
.catch(VK.APIError, console.error)

// this will catch any module errors
.catch(VK.Error, console.error)

// and this will catch any others
.catch(console.error);
```

##### CoffeeScript:

```coffee
# same code as above

VK = require './vk/'
vk = new VK.API

vk.login 'username or phone number', 'password'

.then -> vk.api 'users.get'

.then (users) ->
  user = users[0]
  name = user.first_name + ' ' + user.last_name
  console.log name
  vk.api 'friends.get', count: 5

.then (friends) ->
  console.log friends
  friends.items

.map (friend) ->
  vk.api 'photos.get',
    owner_id: friend
    album_id: 'profile'
    count: 1, rev: 1, photo_sizes: 1

  .then (response) ->
    photo = response.items[0]
    largestPhotoURL = photo
      .sizes[photo.sizes.length - 1].src
    console.log 'Done for id:', friend
    largestPhotoURL

.then console.log
.catch VK.APIError, console.error
.catch VK.Error, console.error
.catch console.error
```
