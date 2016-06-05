
ipfsIPLD = require 'ipfs-ipld'
ipld = require 'ipld'
Canvas = require 'canvas'
Image = Canvas.Image
bluebird = require 'bluebird'

# TODO: use a plain JS object or class, with have save/load to IPLD/MerkleDAG
serializeImage = (shape, tiles) ->
  image =
    'ipld-image-version': 1
    # derivedfrom: { '\': Image }
    # canonicalversion: { '\': Image }
    tilesize: { x: 256, y: 256 }
    tiles: shape # FIXME: move this to be part of the TileList (on each level)? .shape and .tiles 
    #  boundary:
    #    x: 10
    #    y: 10
    #    width: 1000
    #    height: 1000
    # mipmap structure containing the image data

  # FIXME: put the incoming tiles into the correct structure here

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

round2 = (n) ->
  return 2*Math.ceil(n/2)

mapPyramid = (shape, func) ->
  level = (basetiles) ->
    return Math.ceil(Math.log2(basetiles))
  levels = Math.max(level(shape.x), level(shape.y))
  console.log 'l', shape, levels
  results = []
  for level in [0..levels]
    div = Math.pow 2, level
    s =
      x: Math.ceil(shape.x/div)
      y: Math.ceil(shape.y/div)
    results.push mapRowColumn(s, (tx, ty) ->  func(tx, ty, level) )
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

  renderTileIntoCanvas = (t) ->
    buffer = tiles[t.index]
    loadImage buffer
    .then (img) ->
      ctx.drawImage img, t.location.x, t.location.y, image.tilesize.x, image.tilesize.y

  bluebird.resolve(indices).map(renderTileIntoCanvas)
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

    indices = mapPyramid shape, (tx, ty, level) ->
      mul = Math.pow 2, level
      location =
        x: tx*tilesize.x*mul
        y: ty*tilesize.y*mul
        width: tilesize.y*mul
        height: tilesize.y*mul
      return { location: location, level: level, tx: tx, ty: ty }

    createTile = (t) ->
      # If this way of downscaling is not good enough, maybe use https://github.com/nodeca/pica
      imageData = ctx.getImageData t.location.x, t.location.y, t.location.width, t.location.height
      tileCanvas = new Canvas tilesize.x, tilesize.y
      buf = tileCanvas.toBuffer()
      tileCtx = tileCanvas.getContext '2d'
      tileCtx.putImageData imageData, 0, 0
      t.canvas = tileCanvas
      return Promise.resolve t

    createLevel = (tiles) ->
      bluebird.resolve(tiles).map createTile

    bluebird.resolve(indices).map createLevel
    .then (levels) ->
      return Promise.resolve { shape: shape, levels: levels }

  .then (data) ->
    Promise.resolve data


module.exports =
  construct: serializeImage
  hash: ipld.multihash
  deserialize: ipld.unmarshal
  render: renderBlob
  tile: imageFromBlob
  

