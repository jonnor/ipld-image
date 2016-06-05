
ipld-image is an attempt to create a structured representation of images on [IPFS](http://ipfs.io/),
that allows to do image processing operations directly on this structure, instead of
having to operate on opaque blobs of serialized images (like a PNG or JPEG).

Primarily this is done by being able to address parts of the image,
both in X/Y, and at multiple levels-of-detail through a tiled mipmap pyramid.

## Status

**0.0.1: Initial proof of concept works**

* `ipld-image-fromblob` can take an image file (PNG), and upload to IPFS as an IPLD image
* `ipld-image-toblob` can take an hash of IPLD image, and render an image file (PNG) from it
* ipld-image is just a working name
* **data format is not stable**
* When working, spec may go to https://github.com/ipfs/specs

See [TODO](#todo) for more details

## Motivation

Images are a huge part of web content today.
Their primarily (only) representation is that of a file, a blob of bytes, which we know nothing about
apart from its [MIME-type](https://en.wikipedia.org/wiki/Media_type).
The file typically contains compressed pixel data, and sometimes some metadata.

### Inefficient processing

So if we want to display the image, we have to download and process the whole file.
For some formats one can stream only the beginning of a file, and from that get a lower-quality
image from it. This is intended to allow [progressive rendering](https://blog.codinghorror.com/progressive-image-rendering/).
Theoretically one could cancel the stream when one deems the quality high-enough, but no web browsers available does this
- and unassisted it cannot know what quality is considered good-enough.

This means that there is no space savings possible.
This is inefficient, and painful - especially on slow pay-per-MB connections as is typical on mobile.
Furthermore due to responsive design, the same image (semantically) may be presented at many different screen sizes,
depending on the layout of the page it is included o.
With smart-cropping the image might be not just rescaled, but also show only a subset of the image.

To solve this today, one typically uses an image processing server which
automatically creates (multiple) down-scaled versions of an image.
Examples include [imgflo-server](https://github.com/imgflo/imgflo-server).

However, the processing server must also download the entire image, even if it knows
that only a downscaled cropped part would be needed.

### Lack of metadata
(addressing this might be out-of-scope for v1)

When receiving a down-scaled image blob, there is (in general) no way to find back the original source image.
This means that for instance author attribution must be side-channeled (and usually is not).

Most processing services strip all metadata in the process of creating versions for display.
In a few cases this can be a benefit, as privacy-invading metadata like geographic location is not present.
But mostly it limits usefulness, like one cannot know which camera settings where used,
so one cannot do after-the-fact projection/lens correction.

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
then at each level up the image resolution is halved in both width and height.
So 2x2=4 tiles at level N becomes 1 tile at level N+1.
A fully mipmapped structure is at most 33% larger than the original image.

This also means that an image at level=2 (1/4 width and height) is
1/16 the number of pixels that needs to be downloaded and processed.

ipld-image uses a mipmapped structure, but instead of each level being a continous buffer,
it is a set of tiles, with each tile containing a encoded piece of the pixel data.

Pseudo-YAML structure.

```yaml
## Image

# IPLD-image protocol version
'ipld-image-version': 1

# The Image this data was derived from, if any
# It SHOULD be used when processing an image, say when overlaying text, changing colors etc
derivedfrom: { '/': Image }

# If lossy compressed, this SHOULD be set to a losslessly compressed version
# If processing an image, and this is set, the client SHOULD use canonicalversion instead of this one
canonicalversion: { '/': Image }

# size of each tile
# The tile size should be such that each Tile is less than the IPFS block size
# Currently block size is 256KB. An 256x256 pixel image with 3-4 bytes per pixel should almost always be under this
tilesize: { x: 256, y: 128 }
# number of tiles spanned.
tiles: { x: 10, y: 15 }

# The size of the image spanned by the tiles (in pixels) is:
# [tilesize.X*tiles.x , tilesize*tiles.y]
# here, 2560px by 1920

# which part of the spanned data is visible
# this allows re-using tiles even doing crops/views which don't
# If not specified, the boundary is implicitly
# x: 0, y: 0, width: tilesize.x*tiles.x, height: tilesize.y*tiles.y
boundary:
  x: 10
  y: 10
  width: 1000
  height: 1000

# mipmap structure containing the image data
level0: { '/': TileList } # n=tiles.x*tiles.y
level1: { '/': TileList } [ .. ] # n/=4
level2: { '/': TileList } # n/=4
...
levelH: { '/': TileList } n=1
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

```yaml
## TileList
# stored in a scanline fashion
# ie: the first tile is at x=0,y=0, then follows y=0, x=1,2,3,4,5 -> (tiles.x-1)
# then everything in y=1. Repeat untill all rows are included
[ { '/': Tile,} { '/': Tile } ... ]
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
* Should one allow multiple representations for a tile? Say different compression/formats
* Should we allow sparse images (some areas not covered by tile).
Problem is then need to spec out what this should be filled, which could be limiting. Transparent chunk?
Also, would not have much space-saving because likely a fully transparent tile will already be (de-duplication is builtin).
Non-rectangular images would have more to gain than... But then also need to be able to specify non-rectangular boundary (polygon etc)
* Should we allow non-uniform chunk sizes? This heavily suggests sparse images also.
However it becomes really tricky to assemble a linear substream for a rectangular image, if chunks can be any size and any location..



## Transformation on the dataformat

`TODO: define usecases which we want the dataformat to support (and which ones are not so important).`

`TODO: write how each of these would be performed on example data`

## TODO

### 0.0.2: Proof of concept

```
2) Then take a downscaled crop of that image (operating on the tiles of higher mipmap level), display as file
3) Take this image as an input, and process (change colors etc), persist result as new image, display this.
```

* Set and respect the `boundary` property
* Actually support mipmap tile pyramid. Building the pyramid, and rendering low-resolution output using higher levels
* Support for rendering out a cropped version / area of interest

### 0.1.0: Minimally useful

* Write tests
* Figure out how to best support IPFS 0.4 (no native IPLD). Use a MerkleDAG object?
Fallback: serialize IPLD structure into database/IPFS as JSON blob?
* Implement support in imgflo-server
* Split out spec from implementation, put into https://github.com/ipfs/specs

### Later

* Support browser/client-side
* Support js-ipfs natively
* Sketch out how this could be used to implement a GeglTileStore, for backing buffers in
[GEGL](http://gegl.org), the image processing library used by imgflo-server and GIMP
* Consider extending for video processing

## Ideas

### Perceptual encoding
Right now, we can deducplicate parts of images when the encoded representation of tiles are identical.
However even the tiniest, impercievable change, like a 1 bit quantification error, will invalidate deduplication.
Some [existing discussion here](https://github.com/ipfs/faq/issues/15), with references to academic papers.

### Direct streaming rendering
Right now each tile is stored as a proper PNG image.
In order to construct an image file for rendering, we decode each of the neccesary tiles,
blit it into an in-memory RGBA image representation, and then encode this as a new PNG file.

What if instead we could store tiles as compressed data (without headers), then
assemble an image file by concatating a new header with a set of such pre-encoded tiles.
This would skip both the decoding and re-encoding steps.
This would reducing neccesary computations and memory usage significantly.

PNG might not be suitable for this, as the encoded stream seems to be in scanline ordering.
It may require storing each scanline of each tile as a separate chunk..

This is primarily of interest when IPLD is the core protocol for IPFS (0.5), and there is
support for IPLD path/selectors including ordering. As that way, one could theoretically
express the rendering of an output image file using only IPFS primitives.


## Related projects

* [IIIF](http://iiif.io/api/presentation/2.1/#status-of-this-document), standard for mipmapped images.
Also [ipfs-iiif](https://gist.github.com/edsilv/97759a93cb7c5f0fedb8178fee5e1dd3)

## Contributors

* [@Kubuxu](https://github.com/Kubuxu)
* [@jonnor](https://github.com/jonnor)
