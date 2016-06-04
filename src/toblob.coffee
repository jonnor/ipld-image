
ipfsAPI = require 'ipfs-api'
image = require './image'

readResponse = (res) ->
  return new Promise (fulfill, reject) ->
    buf = new Buffer 0
    res.on 'error', reject
    .on 'data', (data) ->
      buf = Buffer.concat [buf, data]
    .on 'end', ->
      return fulfill buf

# XXX: maybe this should be called something more like "render"?
exports.main = main = () ->

  # given an IPFS hash of image IPLD
  hash = process.argv[2]

  # fetch and deserialize the Image object
  ipfs = ipfsAPI {host: 'localhost', port: '5001', procotol: 'http'}
  ipfs.block.get(hash)
  .then readResponse
  .then (buffer) ->
    img = image.deserialize buffer
    console.log 'i: ', img
  .catch (e) ->
    console.error e
    process.exit 1

  # TODO:
  # fetch all the tiles
  # assemble a PNG file blob from the file
