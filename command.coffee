dashdash      = require 'dashdash'
fs            = require 'fs'
MeshbluConfig = require 'meshblu-config'
MeshbluHttp   = require 'meshblu-http'
NodeRSA       = require 'node-rsa'

packageJSON = require './package.json'

OPTIONS = [{
  names: ['help', 'h']
  type: 'bool'
  help: 'Print this help and exit.'
}, {
  names: ['version', 'v']
  type: 'bool'
  help: 'Print the version and exit.'
}]

class Command
  constructor: ->
    process.on 'uncaughtException', @die
    {} = @parseOptions()
    @config  = new MeshbluConfig()
    @meshblu = new MeshbluHttp @config.toJSON()

  parseOptions: =>
    parser = dashdash.createParser({options: OPTIONS})
    options = parser.parse(process.argv)

    if options.help
      console.log "usage: e2e-broadcast-bob [OPTIONS]\noptions:\n#{parser.help({includeEnv: true})}"
      process.exit 0

    if options.version
      console.log packageJSON.version
      process.exit 0

    return options

  run: =>
    @setup (error) =>
      return @die error if error?
      console.log 'done'
      process.exit 0

  setup: (callback) =>
    @findOrCreateKeyPair (error) =>
      return callback error if error?
      @updatePublicKey callback

  findOrCreateKeyPair: (callback) =>
    try
      {privateKey, publicKey} = JSON.parse fs.readFileSync './keys.json'
      throw new Error unless privateKey? && publicKey?
      @keys = {privateKey, publicKey}
      return callback null
    catch
      console.warn 'no valid keys.json found, generating new pair'

    key = new NodeRSA()
    key.generateKeyPair()
    privateKey = key.exportKey 'private'
    publicKey  = key.exportKey 'public'
    fs.writeFileSync './keys.json', JSON.stringify({privateKey, publicKey}, null, 2)
    @keys = {privateKey, publicKey}
    callback null

  updatePublicKey: (callback) =>
    deviceUuid = @config.toJSON().uuid
    @meshblu.update deviceUuid, {publicKey: @keys.publicKey}, callback

  die: (error) =>
    return process.exit(0) unless error?
    console.error 'ERROR'
    console.error error.stack
    process.exit 1

module.exports = Command
