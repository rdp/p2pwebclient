require 'rubygems'
require 'sane'
require 'gnuplot' # rdp-gnuplot
ENV['RB_GNUPLOT'] = 'c:\cygwin\bin\gnuplot' if OS.windows?
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
    def add_label(plot, axis, text)
      plot.arbitrary_lines << "set #{axis}label \"#{text}\" font \"Times-Roman,11\""
    end
  
    def plot xs, percentiles, name = 'unnamed.pdf', xlabel = nil, ylabel = nil, xs2 = nil, percentiles2 = nil, legend1_addition = nil, legend2_addition = nil, ymax = nil
      xrange = xs.last - 0

      if(xs2)
        assert(percentiles2)
        # sanity check of matching x axis disabled for now [sigh]
        # assert(xrange == (xs2.last - xs2.first))
        xrange = [xrange, xs2.last - xs2.first].max
      end
      
      xrange_min = 0
      if xs.first < 1       
        xrange_min = (-xrange*0.1).to_i # so we can see it
      end      

      Gnuplot.open do |gp|
        Gnuplot::Plot.new( gp ) do |plot|

          #plot.title  "Example" 
          # we don't need no shtinkin global titles
          add_label(plot, 'y', ylabel) if ylabel
          add_label(plot, 'x', xlabel) if xlabel
    		  above_x = [(xrange*1.05).to_i, xrange + 1].max
          plot.xrange "[#{xrange_min}:#{ above_x }]"
          
          all_points =  percentiles
          if percentiles2
            all_points += percentiles2
          end

          if ymax
            plot.yrange "[0:#{ymax}]"
          else
            plot.yrange "[0:#{all_points.flatten.max * 1.1}]"
          end
          setup_normal plot
          plot.output name
          # if ever useful...
          #plot.logscale 'y' 

          smallest_range = xs.last - xs.first # pick some large value
          previous = xs.first
          for x in xs[1..-1]
            space_between_these_two = x - previous
            smallest_range = [smallest_range, space_between_these_two].min
          end            

          # box_width is only for percentiles
          box_width = [xrange*3/100, smallest_range/2.0].min
          plot.boxwidth box_width
          if xrange >= 100*smallest_range
            add_median_line = false # deemed unuseful for now
          else
            add_median_line = false
          end
          
          add_percentile_plot plot, [xs] + percentiles, legend1_addition, add_median_line
          if(xs2)
            add_percentile_plot plot, [xs2] + percentiles2, legend2_addition, add_median_line
          end

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
    
    def add_percentile_plot plot, all_data, addition_for_legend, add_median_line
      plot.data << Gnuplot::DataSet.new( all_data ) do |ds|
        ds.using = "1:3:2:6:5"
        ds.with = "candlesticks"
        if addition_for_legend
          ds.title = "1,25,75,99 percentiles #{addition_for_legend}"
        else
          ds.notitle 
        end
      end

      #add the median...all it is is a line
      plot.data << Gnuplot::DataSet.new(all_data) do |ds|
        # if you want to connect the median lines...
        if add_median_line
         ds.with = "lines "
         ds.using = "1:4 " # just x,median
        else
         ds.using = "1:4:4:4:4"
         ds.with = "candlesticks lt -1 "
         
       end
       if addition_for_legend
         ds.title = "50th percentile #{addition_for_legend}"
       else
         ds.notitle
       end
        
      end
    end

    def setup_normal plot
      plot.terminal 'pdf monochrome'
     
    end

    #
    # this is for plotting a single line style plot, and yes, only one line currently
    # expect hash_values is like {'abc' => [[1,1], [1,2]...]}
    #
    def plotNormal xlabel, ylabel, hash_values, name
      
      Gnuplot.open do |gp|
        Gnuplot::Plot.new( gp ) do |plot|
          add_label(plot, 'y', ylabel) if ylabel
          add_label(plot, 'x', xlabel) if xlabel
          #plot.xrange "[0:#{ get_smallest_x(hash_values) + 1}]"
          setup_normal plot

          raise unless name.include? 'pdf' # gotta have that
          plot.output name
          ymax = 0
          hash_values.each{|name, data|
            xs = data.map{|x, y| x}
            ys = data.map{|x, y| y}
            ymax = [ymax, ys.max].max
            plot.data << Gnuplot::DataSet.new( [xs, ys]) do |ds|; 
              ds.title = name
              ds.with = 'linespoints'
            end          
          }
          plot.yrange "[0:#{ymax * 1.1}]"
          
        end
      end
    end
    named_args

  end

end
