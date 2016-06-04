
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

loadImage = (encoded) ->
  return new Promise (fufill, reject) ->
    img = new Image
    img.onload = () ->
      return fufill img
    img.onerror = reject
    img.src = encoded

imageFromBlob = (blob, tilesize) ->
  loadImage blob
  .then (img) ->
    canvas = new Canvas img.width, img.height
    ctx = canvas.getContext '2d'
    ctx.drawImage img, 0, 0, img.width, img.height
    return Promise.resolve canvas
  .then (canvas) ->
    shape =
      x: Math.ceil(canvas.width / tilesize.x)
      y: Math.ceil(canvas.height / tilesize.y)
    tiles = []
    for ty in [0...shape.y]
      for tx in [0...shape.x]
        tileCanvas = new Canvas tilesize.x, tilesize.y
        tileImg = new Image
        tileImg.src = tileCanvas.toBuffer()
        location =
          x: tx*tilesize.x
          y: ty*tilesize.y
        ctx = canvas.getContext '2d'
        ctx.drawImage tileImg, 0, 0, tilesize.x, tilesize.y
        tiles.push tileCanvas
    return Promise.resolve { shape: shape, tiles: tiles }
  .then (data) ->
    console.log 't', data
    Promise.resolve data


module.exports =
  repeat: repeatedImage
  construct: serializeImage
  hash: ipld.multihash
  deserialize: ipld.unmarshal
  render: renderBlob
  tile: imageFromBlob
  

