
chai = require 'chai'

describe 'constructing from PNG', ->
  it 'should be available'
  it 'should have a mipmap pyramid of tiles'
  it 'rendering should look identical'

describe 'image with specified boundary', ->
  it 'should render only part inside boundary'

describe 'rendering a cropped version of image', ->
  it 'should give image with size of crop'
  it 'output contains the specified area'

describe 'rendering at lower resolution', ->
  it 'should give image with specified size'
  it 'should be identical to downscaled original'
