
ipfsIPLD = require 'ipfs-ipld'
ipld = require 'ipld'
Canvas = require 'canvas'
Image = Canvas.Image
bluebird = require 'bluebird'

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


# NOTE: only sync
mapRowColumn = (shape, func) ->
  results = []
  for ty in [0...shape.y]
    for tx in [0...shape.x]
      results.push func(tx, ty, shape)
  return results

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

  indices = mapRowColumn shape, (tx, ty) ->
    idx = (ty*shape.x)+tx
    location =
      x: tx*image.tilesize.x
      y: ty*image.tilesize.y
    return { index: idx, location: location }

  renderTile = (t) ->
    buffer = tiles[t.index]
    loadImage buffer
    .then (img) ->
      ctx.drawImage img, t.location.x, t.location.y, image.tilesize.x, image.tilesize.y

  bluebird.resolve(indices).map(renderTile)
  .then (tiles) ->
    Promise.resolve canvas

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
    ctx = canvas.getContext '2d'
    shape =
      x: Math.ceil(canvas.width / tilesize.x)
      y: Math.ceil(canvas.height / tilesize.y)
    tiles = []
    for ty in [0...shape.y]
      for tx in [0...shape.x]
        location =
          x: tx*tilesize.x
          y: ty*tilesize.y
        imageData = ctx.getImageData location.x, location.y, tilesize.x, tilesize.y
        tileCanvas = new Canvas tilesize.x, tilesize.y
        buf = tileCanvas.toBuffer()
        tileCtx = tileCanvas.getContext '2d'
        tileCtx.putImageData imageData, 0, 0
        tiles.push tileCanvas
    return Promise.resolve { shape: shape, tiles: tiles }
  .then (data) ->
    Promise.resolve data


module.exports =
  construct: serializeImage
  hash: ipld.multihash
  deserialize: ipld.unmarshal
  render: renderBlob
  tile: imageFromBlob
  

