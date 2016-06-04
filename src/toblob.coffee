
ipfsAPI = require 'ipfs-api'
image = require './image'
bluebird = require 'bluebird'

fs = require 'fs'

readResponse = (res) ->
  return new Promise (fulfill, reject) ->
    buf = new Buffer []
    res.on 'error', reject
    .on 'data', (data) ->
      buf = Buffer.concat [buf, data]
    .on 'end', ->
      return fulfill buf

savePNGFile = (canvas, path) ->
  return new Promise (fufill, reject) ->
    out = fs.createWriteStream path
    stream = canvas.pngStream()
    stream.on 'data', (chunk) ->
      out.write(chunk);
    stream.on 'end', ->
      return fufill path

fetchTiles = (ipfs, image) ->
  hashes = image.level0.map (tile) -> tile.data['/']
  hashes = bluebird.resolve hashes

  getHash = (h) ->
    ipfs.block.get h
    .then readResponse
    .then (buf) ->
      buf = buf.slice 8
      return buf

  return hashes.map getHash, concurrency: 10

# XXX: maybe this tool be called something more like "render"?
exports.main = main = () ->

  # given an IPFS hash of image IPLD
  hash = process.argv[2]
  outpath = process.argv[3] or 'out.png'

  # fetch and deserialize the Image object
  ipfs = ipfsAPI {host: 'localhost', port: '5001', procotol: 'http'}
  ipfs.block.get(hash)
  .then readResponse
  .then image.deserialize
  .then (img) ->
    fetchTiles ipfs, img
    .then (tiles) ->
      image.render img, tiles
   .then (canvas) ->
    savePNGFile canvas, outpath
  .then (filepath) ->
    console.log filepath
  .catch (e) ->
    console.error e
    process.exit 1

