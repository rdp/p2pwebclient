

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
#f = [6,5.5, 6.5] then pass in [x,b,c,d,e,f]



def do_file filename, ylabel = nil, xlabel = nil
   # expected something like [filename, x axis, y axis]
   # and parse some percentile graphs
   stats = File.read 'number_stats.txt'
   xs = []
   stats.each_line{|line| line =~ /just numbers.*?_at(\d+\.\d+|\d+)/; xs << $1 if $1 }
   readings = eval(File.read(filename))
   # comes to us like [[0.0, 0.0, 0.0, 118003.5, 1200130.5], [0.0, 0.0, 0.0, 319402.5, 1112664.0], [0.0, 0.0, 0.0, 105941.5, 924438.5], [0.0, 0.0, 10860.0, 161322.0, 708114.5], [0.0, 0.0, 10518.0, 159478.5, 679632.0], [0.0, 0.0, 0.0, 171059.5, 731339.0], [0.0, 0.0, 0.0, 5672.0, 786340.5], [0.0, 0.0, 0.0, 79341.0, 966801.0], [0.0, 0.0, 1448.0, 189178.5, 809426.0]]

   # parse it out to rgnuplot style arrays...
   locations = {1 => 0, 25 => 1, 50 => 2, 75 => 3, 99 => 4}
   percentiles = []

   for percentile, location in locations.sort
      new = []
      for reading in readings
         new << reading[location]
      end
      percentiles << new
   end
   puts "percentiles are", percentiles.inspect, xs.inspect

   require 'rubygems'
   require 'gnuplot'

   Gnuplot.open do |gp|
      Gnuplot::Plot.new( gp ) do |plot|

         plot.title  "Example"
         plot.ylabel ylabel if ylabel
         plot.xlabel xlabel if xlabel
         #    plot.xrange "[0:11]"
         #    plot.yrange "[0:10]"

         plot.data << Gnuplot::DataSet.new( [xs] + percentiles ) do |ds|
            ds.using = "1:3:2:6:5"
            # ugly blue      ds.with = "candlesticks lt 3 lw 2 title '1,25,50,75,99th percentiles' "
            ds.with = "candlesticks title '1,25,50,75,99th percentiles' "
            #ds.notitle
         end

         # add the median...kind of...since all it is is a line
         plot.data << Gnuplot::DataSet.new( [xs] + percentiles ) do |ds|
            ds.using = "1:4:4:4:4"
            ds.with = "candlesticks lt -1"
            #      ds.with = "candlesticks"
            ds.notitle
         end

      end
   end
end
require 'rubygems'
require 'optiflag'
if $0 == __FILE__
   module DBChecker extend OptiFlagSet
      optional_flag "file"
      optional_flag "dir"

      and_process!
   end

   do_file ARGV.flags.file if ARGV.flags.file
   if ARGV.flags.dir
     for file in {"
   end

end
