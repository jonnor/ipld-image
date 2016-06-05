
ipfsAPI = require 'ipfs-api'
image = require './image'
bluebird = require 'bluebird'
fs = require 'fs'

readFile = bluebird.promisify fs.readFile

savePNGBuffer = (canvas, path) ->
  return new Promise (fufill, reject) ->
    buf = new Buffer []
    stream = canvas.pngStream()
    stream.on 'error', reject
    stream.on 'data', (chunk) ->
      buf = Buffer.concat [buf, chunk]
    stream.on 'end', ->
      return fufill buf

exports.main = main = () ->

  # take input image blob
  # split into individual tiles, as PNGs (initially level 0 only)
  # upload the tiles to IPFS
  # construct a IPLD Image for these tiles

  inputpath = process.argv[2]
  tilesize =
    x: 256
    y: 256

  # put this IPLD object into IPFS
  ipfs = ipfsAPI {host: 'localhost', port: '5001', procotol: 'http'}

  Promise.resolve(inputpath)
  .then readFile
  .then (buffer) ->
    return image.tile buffer, tilesize
  .then (data) ->
    # upload tiles to IPFS
    upload = (tile) ->
      savePNGBuffer(tile.canvas)
      .then ipfs.block.put
      .then (object) ->
        tile.hash = object.Key
        Promise.resolve tile

    tiles = []
    for level in data.levels
      for t in level
        tiles.push t
    bluebird.resolve(tiles).map upload
    .then (hashes) ->
      img = image.construct data.shape, hashes
      Promise.resolve img
    .then ipfs.block.put
  .then (block) ->
    console.log block.Key
  .catch (e) ->
    console.error e
    process.exit 1
