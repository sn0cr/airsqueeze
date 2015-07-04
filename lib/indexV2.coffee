portastic = require('portastic')
ip = require('ip')
NodeTunes = require('nodetunes')
Nicercast = require('nicercast')
flags = require('flags')
SqueezeServer = require('squeezenode')
Box = require './box'

flags.defineBoolean('diagnostics', false, 'run diagnostics utility')
flags.defineBoolean('version', false, 'return version number')
flags.defineInteger('timeout', 5, 'disconnect timeout (in seconds)')
flags.defineBoolean('verbose', false, 'show verbose output')
flags.defineBoolean('stop', true, 'stop or turn off after the playback stops')
flags.defineString('ip', '127.0.0.1', 'the ip of the squeezebox server')


flags.parse()
squeeze = new SqueezeServer("http://#{flags.get('ip')}", 9000)

if flags.get('version')
  pjson = require('../package.json')
  console.log(pjson.version)

else if flags.get('diagnostics')
  diag = require('./diagnostics')
  diag(squeeze)
else
  console.log('Searching for Squeezeboxes in your network...')
  squeeze.on 'register', =>
    squeeze.getPlayers (reply) ->
      for box in reply?.result
        nBox = new Box(box, flags, squeeze)
