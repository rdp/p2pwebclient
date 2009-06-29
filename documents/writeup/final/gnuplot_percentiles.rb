# 1	1.5	2 	2.4	4	6.
# 2	1.5	3 	3.5	4	5.5
# 3	4.5	5 	5.5	6	6.5
a = [1,2,3]
b = [1.5, 1.5, 4.5]
c = [2,3,5]
d = [2.4, 3.5, 5.5]
e = [4,4,6]
f = [6,5.5, 6.5] 
require 'rubygems'
require 'gnuplot'
Gnuplot.open do |gp|
  Gnuplot::Plot.new( gp ) do |plot|
  
    plot.title  "Example"
    plot.ylabel "x"
    plot.xlabel "x^2"
    plot.xrange "[0:11]"
    plot.yrange "[0:10]"

    plot.data << Gnuplot::DataSet.new( [a,b,c,d,e,f] ) do |ds|
      ds.using = "1:3:2:6:5"
      ds.with = "candlesticks lt 3 lw 2 title 'Quartiles' whiskerbars"
      #ds.notitle
    end

    plot.data << Gnuplot::DataSet.new( [a,b,c,d,e,f] ) do |ds|
      ds.using = "1:4:4:4:4"
      ds.with = "candlesticks lt -1 lw 2"
      ds.notitle
    end
    #require 'ruby-debug'
    #debugger

  end
end

