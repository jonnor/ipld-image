
ipfsAPI = require 'ipfs-api'
image = require './image'

exports.main = main = () ->

  # take input image blob
  # split into individual tiles, as PNGs (initially level 0 only)
  # upload the tiles to IPFS
  # construct a IPLD Image for these tiles

  # FIXME: actuall take input image. Now assumes the tile is pre-existing on IPFS, and is correct size
  hash = process.argv[2]

  shape = { x: 4, y: 3 }
  repeated = image.repeat shape, hash
  m = image.construct shape, repeated

  # put this IPLD object into IPFS
  ipfs = ipfsAPI {host: 'localhost', port: '5001', procotol: 'http'}
  ipfs.block.put(m)
  .then (block) ->
    console.log 'ipfs hash: ', block.Key
  .catch (e) ->
    console.error e
    console.error e.stack if e.stack
    process.exit 1

# FIXME: create the reverse tool, ipld-image-toblob
  # given an IPFS hash of image IPLD
  # fetch and deserialize the Image object
  # fetch all the tiles
  # assemble a PNG file blob from the file
