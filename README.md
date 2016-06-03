
ipld-image is an attempt to create a structured representation of images on [IPFS](http://ipfs.io/),
that allows to do image processing operations directly on this structure, instead of
having to operate on opaque blobs of serialized images (like a PNG or JPEG).

## Status

**Just a crazy idea**. See [TODO](#todo)

* ipld-image is just a working name

## Motivation

Images are a huge part of web content today.
Their primarily (only) representation is that of a file, a blob of bytes, which we know nothing about
apart from its [MIME-type](https://en.wikipedia.org/wiki/Media_type).
The file typically contains compressed pixel data, and sometimes some metadata.

So if we want to display the image, we have to download and process the whole file.
For some formats one can stream only the beginning of a file, and from that get a lower-quality
image from it. This is intended to allow [progressive rendering](https://blog.codinghorror.com/progressive-image-rendering/).
Theoretically one could cancel the stream when one deems the quality high-enough, but no web browsers available does this
- and unassisted it cannot know what quality is considered good-enough.
This means that there is no .


An example of an image processing server is [imgflo-server](https://github.com/imgflo/imgflo-server).

## Background

[IPLD](https://github.com/ipfs/specs/tree/master/ipld) is the Inter Planetary Linked Data format.
It will form the base of [IPFS](http://ipfs.io/), an effort to re-architect Internet protocols
to be peer2peer based on content-addressing. IPLD thus serves a similar role to that of
IP packets in the conventional [Internet protocol stack](https://en.wikipedia.org/wiki/Internet_protocol_suite).

Note: IPFS 0.5 will transition to IPLD as the underlying protocol,
whereas IPFS 0.4 (and earlier) use [MerkleDAG](https://github.com/ipfs/specs/tree/master/merkledag),
a less generic version of the same basic idea.

## Dataformat

A [mipmap](https://en.wikipedia.org/wiki/Mipmap) is an structure for efficiently storing
images at different levels of detail. At the lowest level are the original image in full resolution,
then at each level up the. So 4 tiles at level N becomes 1 tile at level N+1.

ipld-image uses a mipmapped structure, but instead of each level being a continous buffer,
it is a set of tiles, each tile containing a piece of the pixel data.

Pseudo-YAML structure.

```yaml
  ## Image

  # IPLD-image protocol version
  'ipld-image-version': 1

  # size of each tile
  tilesize: { x: 256, y: 128 }
  # number of tiles spanned.
  tiles: { x: 10, y: 15 }

  # The size of the image spanned by the tiles (in pixels) is:
  # [tilesize.X*tiles.x , tilesize*tiles.y]
  # here, 2560px by 1920

  # which part of the spanned data is visible
  # this allows re-using tiles even doing crops/views which don't
  boundary:
    x: 10
    y: 10
    width: 1000
    height: 1000

  # mipmap structure containing the image data
  # stored in a scanline fashion
  # ie: the first tile is at x=0,y=0, then follows y=0, x=1,2,3,4,5 -> (tiles.x-1)
  # then everything in y=1. Repeat untill all rows are included
  level0: [ { '/': Tile,} { '/': Tile } ... ]  # n=tiles.x*tiles.y
  level1: [ .. ] # n/=4
  level2: [ .. ] # n/=4
  ...
  levelH: [ .. ] n=1
```


```yaml
  ## Tile

  # format of data
  format: "png-idat"
  # size of data in pixels
  size: { x: 256, y: 128 }
  # link to the chunk of image data
  data: {"/",  }
```

An advantage of this initial spec is that the `Tile`, containing the image data,
is self-describing yet has. This should allow reusing the Tile


Open questions

* Is storing all levels as part of image the best approach?
Alternatives are:
a) Let each level link to level above and/or above.
b) let each tile link to the tiles on the level under. This means a lot of indirection
* How to deal with fact that non-square images will not reduce down to a level with single. 
Must one render transparency into chunks then?
Kind-of a case where we get sparse-ness further up in the mipmaps
* What would be good initial format. Should probably be lossless compression.
PNG is most widely supported. Both JPEG-LS, JPEG2000, JPEG XR and WebP seems to be be pretty poorly supported...
* Should one allow multhiple representations for a tile? Say different compression/formats
* Should we allow sparse images (some areas not covered by tile).
Problem is then need to spec out what this should be filled, which could be limiting. Transparent chunk?
Also, would not have much space-saving because likely a fully transparent tile will already be (de-duplication is builtin).
Non-rectangular images would have more to gain than... But then also need to be able to specify non-rectangular boundary (polygon etc)
* Should we allow non-uniform chunk sizes? This heavily suggests sparse images also.
However it becomes really tricky to assemble a substream.

## Transformation on the dataformat

`TODO: define usecases which we want the dataformat to support (and which ones are not so important).`
`TODO: write how each of these would be performed on example data`

## TODO

### 0.0.1: Proof of concept

* Define an initial dataformat for a tile-based, mipmapped datastructure for images
* Prototype some code using this format
* Figure out if and how one can make a valid image by a concatinating tile together
* Define and make an initial proof of concept.
1) Be able to take an input blob image, convert it into IPLD image representation, push into IPFS.
2) Then take a downscaled crop of that image (operating on the tiles of higher mipmap level), display as file
3) Take this image as an input, and process (change colors etc), persist result as new image, display this.

## 0.1.0: Minimally useful

* Can we do this without IPFS 0.5??
For instance by putting the serialized IPLD structure into database/IPFS as a blob (JSON)?
* Implement support in imgflo-server
* Split out spec from implementation

## Later

* Sketch out how this could be used to implement a GeglTileStore, for backing buffers in
[GEGL](http://gegl.org), the image processing library used by imgflo-server and GIMP
