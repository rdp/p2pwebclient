# expected something like [filename, x axis, y axis]
# and parse some percentile graphs
stat = File.read 'number_stats.txt'
numbers = []
stats.each_line{|line| line =~ /just numbers.*?_at(\d+\.\d+|\d+)/; number << $1 $1 }
puts numbers.inspect



# gnuplot expects something like
# x    1st     25th    50th   75th    99th
# 1    1.5     2       2.4     4       6.
# 2    1.5     3       3.5     4       5.5
# 3    4.5     5       5.5     6       6.5
#x = [1,2,3]
#b = [1.5, 1.5, 4.5]
#c = [2,3,5]
#d = [2.4, 3.5, 5.5]
#e = [4,4,6]
#f = [6,5.5, 6.5]

x =  numbers
numbers = [[799.98, 1330.81, 1604.27, 1945.76, 2555.93], [833.85, 1115.37, 1228.83, 1416.25, 1867.09], [919.66, 1054.67, 1123.94, 1249.02, 1707.25], [773.26, 905.26, 972.88, 1080.27, 1634.38], [247.47, 889.17, 931.92, 1002.24, 1266.23], [810.28, 869.11, 901.46, 986.36, 1355.63], [739.22, 834.95, 876.03, 926.65, 1636.65]]

require 'rubygems'
require 'gnuplot'

Gnuplot.open do |gp|
  Gnuplot::Plot.new( gp ) do |plot|
  
    plot.title  "Example"
    plot.ylabel ARGV[1]
    plot.xlabel ARGV[2]
#    plot.xrange "[0:11]" # TODO
#    plot.yrange "[0:10]"

    plot.data << Gnuplot::DataSet.new( [x,b,c,d,e,f] ) do |ds|
      ds.using = "1:3:2:6:5"
      ds.with = "candlesticks lt 3 lw 2 title 'Quartiles' whiskerbars"
      #ds.notitle
    end

    # add median...kind of...
    plot.data << Gnuplot::DataSet.new( [x,b,c,d,e,f] ) do |ds|
      ds.using = "1:4:4:4:4"
      ds.with = "candlesticks lt -1 lw 2"
      ds.notitle
    end
    #require 'ruby-debug'
    #debugger

  end
end

