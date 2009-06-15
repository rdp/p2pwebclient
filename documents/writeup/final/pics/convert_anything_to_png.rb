require 'rubygems'
require 'RMagick'
# seems broken at least on linux!
include Magick
for arg in ARGV do
  im = ImageList.new(arg)

  im.write(arg.split('.')[0..-2].join('.') + '.png')
end
