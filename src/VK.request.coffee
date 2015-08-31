VK      = require '../'
Promise = require 'bluebird'
request = require 'request'

Promise.promisifyAll VK.request =
  Promise.promisify request.defaults
    followAllRedirects: true
