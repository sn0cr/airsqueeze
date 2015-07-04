ip = require('ip')
SqueezeServer = require('squeezenode')
module.exports = (squeeze)->
  console.log('AirSqueeze Diagnostics')
  console.log('node version\t', process.version)
  console.log('operating sys\t', process.platform, '(' + process.arch + ')')
  console.log('ip address\t', ip.address())

  console.log('\nSearching for Squeezeboxes in your network...')

  squeeze.on 'register', ->
    squeeze.getPlayers (reply) ->
      for box in reply.result
        delete box.uuid
        delete box.playerid
        console.log JSON.stringify box, null, 2
module.exports()
