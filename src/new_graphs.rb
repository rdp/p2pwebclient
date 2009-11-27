require 'constants'

unless $skip_gruff
 require 'gruff'
end
#require File.dirname(__FILE__) + '/base'
require 'pp'
require 'lib/ruby_useful_here.rb'

class Array
  def middle
    self[self.length/2]
  end
end

class PointLine < Gruff::Base # shamelessly lifted from Line ltodo add Gruff back and figure out how to make it work

  # Draw a dashed line at the given value
  attr_accessor :baseline_value
	
  # Color of the baseline
  attr_accessor :baseline_color
  
  # Hide parts of the graph to fit more datapoints, or for a different appearance.
  attr_accessor :hide_dots, :hide_lines
  attr_accessor :maximum_value, :minimum_value, :maximum_x, :minimum_x # I like these :)

  # Call with target pixel width of graph (800, 400, 300), and/or 'false' to omit lines (points only).
  #
  #  g = Gruff::Line.new(400) # 400px wide with lines
  #
  #  g = Gruff::Line.new(400, false) # 400px wide, no lines (for backwards compatibility)
  #
  #  g = Gruff::Line.new(false) # Defaults to 800px wide, no lines (for backwards compatibility)
  # 
  # The preferred way is to call hide_dots or hide_lines instead.


  def initialize(*args)
    raise ArgumentError, "Wrong number of arguments" if args.length > 2
    if args.empty? or ((not Numeric === args.first) && (not String === args.first)) then
      super()
    else
      super args.shift
    end
    @sort = false
    # ltodo test for non lines
    @hide_dots = @hide_lines = false
    @baseline_color = 'red'
    @baseline_value = nil
    @doDrawTheseLines  = nil
  end
  
    def data(name, data_points_duples, color=nil)
      if data_points_duples.class != Array
        print "ACK NON ARRAY FOR DATA!"
      end
      if @data == [] # eureka our first data call! or something!
        @has_data = true
        # put here to keep compatibility with these originating as nil
        raise unless data_points_duples.class == Array
        firstEntry = data_points_duples[0]
        if firstEntry.class != Array
          print "ERR we only accept duples!"
        end
        if firstEntry[1].class == Array # percentiel array
          @maximum_value = firstEntry[1][-1]
          @minimum_value = firstEntry[1][0]
        else
          @maximum_value = firstEntry[1]
          @minimum_value = firstEntry[1]
        end
# now the x's
        @column_count = firstEntry[0] # ltodo use of column_count is odd...
        @minimum_x = firstEntry[0]
        @maximum_x = firstEntry[0]
      end
      
      @data << [name, data_points_duples, (color || increment_color)] # data is a triple of name, points, color
      # Set column count if this is larger than previous counts
      @column_count = [@column_count, data_points_duples[-1][0]].max # make it bigger if this is indeed larger
      
      # Pre-normalize
      data_points_duples.each_with_index do |data_point, index|
        raise unless @maximum_value and data_point[1] and data_point[0] # x, y
        if data_point[1].class == Array # percentile array
          @maximum_value = [@maximum_value, data_point[1][-1]].max
          @minimum_value = [@minimum_value, data_point[1][0]].min
        else
          @maximum_value = [@maximum_value, data_point[1]].max
          @minimum_value = [@minimum_value, data_point[1]].min
        end
          
        @maximum_x = [@maximum_x, data_point[0]].max
        @minimum_x = [@minimum_x, data_point[0]].min
      end
    end
    
    def rightMostPoint
      return @column_count
    end

    def normalizePoint(x, y)
      return [(x - @minimum_x) / @spreadX, (y - @minimum_value ) / @spread]
    end
    
    def normalizeHere(force=false)

      # our own normalize :) ltodo why not working?
      if @norm_data.nil? || force
        @norm_data = []
        return unless @has_data
                
        calculate_spread # here is where it gets maxes
        @spreadY = @spread.to_f
        @spreadX = @maximum_x - @minimum_x.to_f
        # typically @data is [name, [[x,y], [x, y]]
        # for percentile arays I want it as [name, [[x, [y,y,y]]]]
        
        @data.each do |data_row_of_duples|
          norm_data_points = []
          data_row_of_duples[DATA_VALUES_INDEX].each do |data_point_duple|
              if data_point_duple[1].class == Array
                x = normalizePoint(data_point_duple[0], 0)[0] # get the x value
                ys = data_point_duple[1].map{|y| normalizePoint(0, y)[1]}
                norm_data_points << [x, ys]
              else
                x = data_point_duple[0]
                y = data_point_duple[1]
                norm_data_points << normalizePoint(x, y)
              end
          end
          @norm_data << [data_row_of_duples[DATA_LABEL_INDEX], norm_data_points, data_row_of_duples[DATA_COLOR_INDEX]]
        end
      end
    end


  def offsetXForThisGraph(x)
    @graph_left + x * graph_width
  end

  
  def offsetYForThisGraph(data_point)
      @graph_top + (@graph_height - data_point * @graph_height)
  end
   
  def draw # pointline
    super false # don't setup those normal things :)
    return unless @has_data
    normalizeHere # ltodo look into normalize not working, or not 'calling out' or what not
    
    if (defined?(@norm_baseline)) then
      level = @graph_top + (@graph_height - @norm_baseline * @graph_height)
      @d = @d.push
      @d.stroke_color @baseline_color
      @d.fill_opacity 0.0
      @d.stroke_dasharray(10, 20)
      @d.stroke_width 5
      @d.line(@graph_left, level, @graph_left + @graph_width, level)
      @d = @d.pop
    end

    #@data has it all, and the scales are setup right :)
    #
    # Let's see...say it ranges from 0 to 2 [0..2] and then is 350 wide.  and I have a point at ".5"
    # it should be about 75, or .5/spreadX*width


    if @labels.empty? and not @hide_line_markers
    # ltodo let's make our own :)
    # ltodo    0.upto(5)
      print "warning -- no labels given us! drawing none"
    end
    for position, label in @labels # ltodo make sure it is valid if position < @minimum_x
      x_offset = normalizePoint(position, -1)[0]
      x_offset = offsetXForThisGraph(x_offset)
      draw_label(x_offset, position)
    end    


    @norm_data.each_with_index do |data_row, index|      
      prev_x = prev_y = nil
      data_row[1].each do |x, y| # ltodo DATA_LOCATION or what not :)
        new_x = offsetXForThisGraph(x)
        unless y.class == Array
          new_y = offsetYForThisGraph(y)
        else
          new_y = offsetYForThisGraph(y.middle)
        end

        # do the line between points
        # Reset each time to avoid thin-line errors
        reset_line_stroke data_row

        if !@hide_lines and !prev_x.nil? and !prev_y.nil? then
          @d = @d.line(prev_x, prev_y, new_x, new_y)
        end
        
        # do the point
        circle_radius = point_radius
        @d = @d.circle(new_x, new_y, new_x - circle_radius, new_y) unless @hide_dots
        
        
        prev_x = new_x
        prev_y = new_y
        
        
        # now we have y with lots a points
        # we want a stroke...um...straight up [same thickness] to the next point,  then the next point, then straight up [thinner] to the next
        if y.class == Array
          assert y.length % 2 == 1, 'we assume odd percentiles count for now!'
          steps_to_draw_in_both_directions = y.length / 2
          middle = y.length / 2
          x_stays_same = new_x
          percentile_prev_up_y = new_y
          percentile_prev_down_y = new_y
          steps_to_draw_in_both_directions.times do |how_far_away|
            up_pixel_y = offsetYForThisGraph(y[middle + how_far_away + 1])
            down_pixel_y = offsetYForThisGraph(y[middle - how_far_away - 1])
            reset_line_stroke data_row, 1.0/(how_far_away + 1), increment_color
            
            #@d = @d.line(x_stays_same, percentile_prev_up_y, x_stays_same, up_pixel_y)
            #@d = @d.line(x_stays_same, percentile_prev_down_y, x_stays_same, down_pixel_y)
            percentile_prev_up_y = up_pixel_y
            percentile_prev_down_y = up_pixel_y
            circle_radius = point_radius/(how_far_away + 2)
            
            @d = @d.circle(x_stays_same, up_pixel_y, x_stays_same - circle_radius, up_pixel_y)# unless @hide_dots
            @d = @d.circle(x_stays_same, down_pixel_y, x_stays_same - circle_radius, down_pixel_y)# unless @hide_dots

          end
        end  
      end

    end

    @d.draw(@base_image)
  end

 def reset_line_stroke data_row, width_multiplier_for_making_smaller = 1, color = nil
   color ||= data_row[DATA_COLOR_INDEX]
   @d = @d.stroke color
   @d = @d.fill color
   @d = @d.stroke_opacity 1.0
   @d = @d.stroke_width clip_value_if_greater_than(@columns / (@norm_data.first[1].size * 4), 5.0) * width_multiplier_for_making_smaller
 end
   
 def point_radius
   clip_value_if_greater_than(@columns / (@norm_data.first[1].size * 2.5), 5.0)
 end

 def tellMePercentiles(percentiles_only)
   @doDrawTheseLines = percentiles_only
 end
 
 def normalize(force=true) # ltodo is this new?  this seems never called, actually ltodo should it be? replace with "my 
    print 'my normalize for real'
    @maximum_value = [@maximum_value.to_f, @baseline_value.to_f].max
    super
    @norm_baseline = (@baseline_value.to_f / @maximum_value.to_f) if @baseline_value
  end

# ltodo tell ruby that args encapsulates (or seems to) poorly
 def PointLine.create(name, points)
 a = PointLine.new
 a.data("fake", points)
 a.write(name)
 end
 
  def PointLine.testSelf
    print "pointline testself"
    create("test/2.png", [[0,1],[1,2],[2,1]])
    create("test/3_pointers.png", [[0,0], [0,1.5], [-1, -1], [2, 3]])
    points = [[0,1],[1,2],[2,1]]
    a = PointLine.new
    a.data("fake", points)
    a.labels = {
      0 => '0', 
      1 => '1', 
#      2 => '5/24', 
#      3 => '5/30', 
    }
    a.write("test/labels.png")
   
  end

  
end

require 'percentile_graph'

class ScatterPlot2 < PointLine
  # ltodo initialize 'draw lines false' and draw_legend false
  # ltodo legend muhaha :)
  def dataSinglePoint(name, data_point, color=nil)
    data(name, [data_point], color) # make it into a 2-d array :)
  end
  alias2 :draw_old => :draw
  def draw
    draw_old
  end

  def point_radius
     1
  end
end

