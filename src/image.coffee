
ipfsIPLD = require 'ipfs-ipld'
ipld = require 'ipld'
Canvas = require 'canvas'
Image = Canvas.Image

# TODO: use a plain JS object or class, with have save/load to IPLD/MerkleDAG
serializeImage = (shape, tilehashes) ->
  image =
    'ipld-image-version': 1
    # derivedfrom: { '\': Image }
    # canonicalversion: { '\': Image }
    tilesize: { x: 256, y: 256 }
    tiles: shape
    #  boundary:
    #    x: 10
    #    y: 10
    #    width: 1000
    #    height: 1000
    # mipmap structure containing the image data

  # FIXME: make list be a link, to follow spec
  image.level0 = []
  for h in tilehashes
    tile =
      format: 'png'
      size: image.tilesize
      data: link(h)
    image.level0.push tile

  # TODO: add upper levels of mipmap pyramid
  # level1: { '\': TileList } [ .. ] # n/=4

  marshalled = ipld.marshal image
  return marshalled

link = (hash) ->
  return { '/': hash }

repeatedImage = (shape, tilehash) ->
  tiles = []
  for y in [0...shape.y]
    for x in [0...shape.x]
      tiles.push tilehash
  return tiles

# TODO: don't instead render into memory, find out how to concat PNG IDAT chunks
# TODO: handle fetching of tiles dynamically, take ipfs as argument
# TODO: support cropping
# TODO: support downscaling by accessing mipmap structure
renderBlob = (image, tiles) ->
  imageSize =
    x: image.tilesize.x*image.tiles.x
    y: image.tilesize.y*image.tiles.y

  canvas = new Canvas imageSize.x, imageSize.y
  ctx = canvas.getContext '2d'

  shape = image.tiles

  blits = []

  for y in [0...shape.y]
    for x in [0...shape.x]
      idx = (y*shape.y)+x
      tileBuffer = tiles[idx]

      tileImg = new Image

      location =
        x: x*image.tilesize.x
        y: y*image.tilesize.y
      tileImg.onerror = (err) ->
        throw err
      tileImg.onload = () ->
        ctx.drawImage tileImg, location.x, location.y, image.tilesize.x, image.tilesize.x
      tileImg.src = tileBuffer

  return canvas

module.exports =
  repeat: repeatedImage
  construct: serializeImage
  hash: ipld.multihash
  deserialize: ipld.unmarshal
  render: renderBlob

