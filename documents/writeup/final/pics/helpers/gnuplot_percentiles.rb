require 'rubygems'
ENV['RB_GNUPLOT'] = '\cygwin\bin\gnuplot'# tell it where it is
require 'gnuplot'
require 'optiflag'

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

def plot xs, percentiles, name = 'demo1.pdf', xlabel = nil, ylabel = nil
  xrange = xs.last - xs.first
  Gnuplot.open do |gp|
    Gnuplot::Plot.new( gp ) do |plot|

      #plot.title  "Example"
      plot.ylabel ylabel if ylabel
      plot.xlabel xlabel if xlabel
      plot.xrange "[0:#{ xs.last + 1}]"
      #    plot.yrange "[0:10]" auto calculated
      # is there an xmin?
      plot.terminal 'pdf'
      plot.output name

      add_percentile_plot plot, [xs] + percentiles

      box_width = xrange*3/100
      plot.boxwidth box_width

    end
  end
end

def add_percentile_plot plot, all_data
  plot.data << Gnuplot::DataSet.new( all_data ) do |ds|
    ds.using = "1:3:2:6:5"
    ds.with = "candlesticks title '1,25,75,99 percentiles' "
  end

  #add the median...all it is is a line
  plot.data << Gnuplot::DataSet.new( all_data) do |ds|
    #  ds.using = "1:4:4:4:4"
    #  ds.with = "candlesticks lt -1"
    #  ds.notitle
    ds.with = "lines title '50 percentile'"
    ds.using = "1:4" # just x,median
  end
end

