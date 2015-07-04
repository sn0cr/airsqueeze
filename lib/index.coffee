portastic = require('portastic')
ip = require('ip')
NodeTunes = require('nodetunes')
Nicercast = require('nicercast')
flags = require('flags')
SqueezeServer = require('squeezenode')

flags.defineString('ip', '127.0.0.1', 'the ip of the squeezebox server')
flags.defineBoolean('diagnostics', false, 'run diagnostics utility')
flags.defineBoolean('version', false, 'return version number')
flags.defineInteger('timeout', 5, 'disconnect timeout (in seconds)')
flags.defineBoolean('verbose', false, 'show verbose output')
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
        deviceName = box.name

        console.log('Setting up AirSqueeze for', deviceName, '{' + box.ip + '}')

        airplayServer = new NodeTunes({
          serverName: deviceName + ' 🎵',
          verbose: flags.get('verbose'),
          controlTimeout: flags.get('timeout')
        })

        clientName = 'AirSqueeze'
        airplayServer.on 'clientNameChange', (name) =>
          clientName = 'AirSqueeze @ ' + name


        airplayServer.on 'error', (err) ->
          if err.code is 415
            console.error('Warning!', err.message)
            console.error('AirSqueeze currently does not support codecs used by applications such as iTunes or AirFoil.')
            console.error('Progress on this issue: https://github.com/stephen/nodetunes/issues/1')
          else
            console.error('Unknown error:')
            console.error(err)


        airplayServer.on 'clientConnected', (audioStream) =>
          portastic.find {
            min : 8000,
            max : 8050,
            retrieve: 1
          }, (err, port) =>
            throw err if err?

            icecastServer = new Nicercast(audioStream, {
              name: 'AirSqueeze @ ' + deviceName
            })

            airplayServer.on 'metadataChange', (metadata) =>
              console.dir metadata
              if metadata.minm
                asar = if metadata.asar?
                  ' - ' + metadata.asar
                else
                  ''
                asal = if metadata.asal?
                  ' - ' + metadata.asal
                else
                  ''
                metadata = metadata.minm + asar + asal
                console.log "sent metadata: #{metadata}"
                icecastServer.setMetadata(metadata)


            airplayServer.on 'clientDisconnected', ->
              icecastServer.stop()

            icecastServer.start(port)
            streamUrl = 'http://' + ip.address() + ':' + port + '/listen.m3u'
            console.log "should play on #{streamUrl}"
            squeeze.request box.playerid, [ "playlist", "play", streamUrl, "Airplay Stream"], (data) ->
              console.log "Got data on requesting playback:"
              console.dir data
            # console.log
            #   uri: 'x-rincon-mp3radio://' + ip.address() + ':' + port + '/listen.m3u'
            #   metadata:
            #     '<?xml version="1.0"?>' +
            #     '<DIDL-Lite xmlns:dc="http://purl.org/dc/elements/1.1/" xmlns:upnp="urn:schemas-upnp-org:metadata-1-0/upnp/" xmlns:r="urn:schemas-rinconnetworks-com:metadata-1-0/" xmlns="urn:schemas-upnp-org:metadata-1-0/DIDL-Lite/">' +
            #     '<item id="R:0/0/49" parentID="R:0/0" restricted="true">' +
            #     '<dc:title>' + clientName + '</dc:title>' +
            #     '<upnp:class>object.item.audioItem.audioBroadcast</upnp:class>' +
            #     '<desc id="cdudn" nameSpace="urn:schemas-rinconnetworks-com:metadata-1-0/">SA_RINCON65031_</desc>' +
            #     '</item>' +
            #     '</DIDL-Lite>'

        airplayServer.on 'clientDisconnected', =>
          # device.stop(->)
          # stop the playback
          console.log "Stop playback"
          # stops the squeezebox
          squeeze.request box.playerid, ["stop"], (data) ->
              console.log "Got data on requesting stop:"
              console.dir data
          # alternatively you could turn it off:
          # squeeze.request box.playerid, ["power", "0"], (data) ->
          # console.log "Got data on requesting power off:"
          # console.dir data
        airplayServer.on 'volumeChange', (vol) =>
          vol = 100 - Math.floor(-1 * (Math.max(vol, -30) / 30) * 100)
          # set volume
          squeeze.players[box.playerid].setVolume(vol)
          console.log "Should set volume to: " + vol

        airplayServer.start()
