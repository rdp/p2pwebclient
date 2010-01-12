require 'rubygems'
require 'sane' # #assert
require 'gnuplot' # rogerdpack-gnuplot
ENV['RB_GNUPLOT'] = '\cygwin\bin\gnuplot' if OS.windows?# tell it where it is by default...
require 'arguments' # rogerdpack-arguments

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
class P2PPlot
  class << self
    def plot xs, percentiles, name = 'demo1.pdf', xlabel = nil, ylabel = nil, xs2 = nil, percentiles2 = nil, legend1_addition = nil, legend2_addition = nil
      xrange = xs.last - xs.first

      if(xs2)
        assert(percentiles2)
        # sanity check of matching x axis disabled for now [sigh]
        # assert(xrange == (xs2.last - xs2.first))
        xrange = [xrange, xs2.last - xs2.first].max
      end

      Gnuplot.open do |gp|
        Gnuplot::Plot.new( gp ) do |plot|

          #plot.title  "Example" 
          # we don't need no shtinkin titles
          plot.ylabel ylabel if ylabel
          plot.xlabel xlabel if xlabel
          plot.xrange "[0:#{ xs.last + 1}]"
          
          all_points =  percentiles
          if percentiles2
            all_points += percentiles2
          end
          plot.yrange "[0:#{all_points.flatten.max * 1.1}]"
          plot.terminal 'pdf'
          plot.output name
          #plot.logscale 'y'

          add_percentile_plot plot, [xs] + percentiles, legend1_addition
          if(xs2)
            add_percentile_plot plot, [xs2] + percentiles2, legend2_addition
          end

          smallest_range = xs.last - xs.first
          previous = xs.first
          for x in xs[1..-1]
            space_between_these_two = x - previous
            smallest_range = [smallest_range, space_between_these_two].min
          end            

          # box_width is only for percentiles
          box_width = [xrange*3/100, smallest_range/2.0].min
          plot.boxwidth box_width

        end
      end
    end


    def get_smallest_x hash_values
      all_xs = []
      hash_values.each{ |line_name, settings|
        settings.each{|x, y|  all_xs << x }
      }
      all_xs.min
    end


    def add_percentile_plot plot, all_data, addition_for_legend = nil
        plot.data << Gnuplot::DataSet.new( all_data ) do |ds|
        ds.using = "1:3:2:6:5"
        ds.with = "candlesticks title '1,25,75,99 percentiles #{addition_for_legend}' "
        #ds.notitle 
      end

      #add the median...all it is is a line
      plot.data << Gnuplot::DataSet.new(all_data) do |ds|
        ds.using = "1:4:4:4:4"
        ds.with = "candlesticks lt -1 title '50th percentile #{addition_for_legend}'"
        #ds.notitle
        
        # if you want to connect the median lines...
        #ds.with = "lines "
        #ds.using = "1:4" # just x,median
      end
    end


    #
    # this is for plotting a single line style plot, and yes, only one line currently
    # expect hash_values is like {'abc' => [[1,1], [1,2]...]}
    #
    def plotNormal xlabel, ylabel, hash_values, name
      
      Gnuplot.open do |gp|
        Gnuplot::Plot.new( gp ) do |plot|
          plot.ylabel ylabel
          plot.xlabel xlabel
          #plot.xrange "[0:#{ get_smallest_x(hash_values) + 1}]"
          plot.terminal 'pdf'
          raise unless name.include? 'pdf' # gotta have that
          plot.output name
          ymax = 0
          hash_values.each{|name, data|
            xs = data.map{|x, y| x}
            ys = data.map{|x, y| y}
            ymax = [ymax, ys.max].max
            plot.data << Gnuplot::DataSet.new( [xs, ys]) do |ds|; 
              ds.title = name
              ds.with = 'lines'
            end          
          }
          plot.yrange "[0:#{ymax * 1.1}]"
          
        end
      end

    end

    named_args


  end

end

