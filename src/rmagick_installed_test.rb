# from http://codesnippets.joyent.com/tag/rmagick
require 'rubygems'
require 'RMagick' # Don't use a capital 'R'.

canvas = Magick::Image.new(240, 300,
              Magick::HatchFill.new('white','lightcyan2'))
gc = Magick::Draw.new

gc.fill('red')
gc.stroke('blue')
gc.stroke_width(2)
gc.path('M120,150 h-75 a75,75 0 1, 0 75,-75 z')
gc.fill('yellow')
gc.path('M108.5,138.5 v-75 a75,75 0 0,0 -75,75 z')
gc.draw(canvas)
File.delete('path.gif') rescue nil
canvas.write('path.gif')
puts "worked?:", File.exist?('path.gif')
