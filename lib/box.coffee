portastic = require('portastic')
ip = require('ip')
NodeTunes = require('nodetunes')
Nicercast = require('nicercast')

module.exports = class Box
  constructor: (box, @flags, @squeeze) ->
    @name = @getName(box)
    @playerId = box.playerid
    @log('Setting up AirSqueeze for', @name, '{' + box.ip + '}')
    @airplayServer = new NodeTunes
      serverName: @name
      verbose: @flags.get('verbose')
      controlTimeout: @flags.get('timeout')
    @clientName = 'AirSqueeze'
    @airplayServer.on 'clientNameChange', (name) =>
      @clientName = 'AirSqueeze @ ' + name
    @airplayServer.on 'error', @errorHandler
    @airplayServer.on 'clientConnected', @onClient
    @airplayServer.on 'clientDisconnected', @onDisconnect
    @airplayServer.on 'volumeChange', @onVolumeChange
    @airplayServer.start()
  onVolumeChange: (vol) =>
    vol = 100 - Math.floor(-1 * (Math.max(vol, -30) / 30) * 100)
    # set volume
    @squeeze.players[@playerId].setVolume(vol)
    console.log "Should set volume to: " + vol
  onDisconnect: =>
    # stop the playback
    console.log "Stop playback on #{@name}"
    # stops the squeezebox
    if @flags.get 'stop'
      @squeeze.request @playerId, ["stop"], (data) =>
        @log "Got data:"
        @log data
    else
      # alternatively you could turn it off:
      @squeeze.request @playerId, ["power", "0"], (data) =>
        @log "Got data:"
        @log data
  errorHandler: (err) =>
    if err.code is 415
      console.error('Warning!', err.message)
      console.error('AirSqueeze currently does not support codecs used by applications such as iTunes or AirFoil.')
      console.error('Progress on this issue: https://github.com/stephen/nodetunes/issues/1')
    else
      console.error('Unknown error:')
      console.error(err)
  getName: (box) =>
    box.name
  log: (args...) =>
    console.log args...
  onClient: (audioStream) =>
    portastic.find {
      min : 8000,
      max : 8050,
      retrieve: 1
    }, (err, port) =>
      throw err if err?
      icecastServer = new Nicercast audioStream, {name: 'AirSqueeze @ ' + @name}
      @airplayServer.on 'metadataChange', (metadata) =>
        @log metadata
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
          @log "sent metadata:"
          @log metadata
          icecastServer.setMetadata(metadata)
          squeezeboxText = encodeURI(metadata)
          @squeeze.request @playerId, [ "display", squeezeboxText], (data) =>
            @log "Got data:"
            @log data

      @airplayServer.on 'clientDisconnected', ->
        icecastServer.stop()

      icecastServer.start(port)
      streamUrl = 'http://' + ip.address() + ':' + port + '/listen.m3u'
      @log "Playing back:", streamUrl
      @squeeze.request @playerId, [ "playlist", "play", streamUrl, "Airplay Stream"], (data) =>
        @log "Got data:"
        @log data
