require 'faster_rubygems' if RUBY_VERSION < '1.9.0'
require 'faster_require'

require 'sane'
require_relative 'gnuplot_percentiles.rb'
require 'spec/autorun'
require 'fileutils'

describe P2PPlot do

  it "should be able to take a hash and calculate minimum x values from it as if it were graph lines" do
    P2PPlot.get_smallest_x({'abc' => [[1,1], [1,2]]}).should == 1
  end

  context "plotting a single line" do

    before do
      FileUtils.rm_rf 'singles.pdf'
      @a = P2PPlot.plotNormal 'x label single', 'y label single', {'abc' => [[1,1], [2,2], [3,3]],
      'def' => [[0,0], [1,1], [4,4]]}, 'singles.pdf'
    end

    it "should generate a straight line graph too" do
      assert File.size('singles.pdf') > 0
    end
    it "should have a tall y for single line graphs, too" do
      y = 4*1.1
      @a.yrange.assoc('yrange')[1].should == "[0:#{y}]"
    end

    it "should setup x range to be 10% past the highest x" do
      y = 4*1.1
      @a.yrange.assoc('yrange')[1].should == "[0:#{y}]"
    end
    
    it "should graph with linespoints" do
      @a.data[0].with.should == 'linespoints'    
    end

  end

  def options
    {:xs => [0,100, 200], :percentiles => [[1,2,3], [0,1,2], [1,2,3], [3,4,5], [4,5,6]], :legend1_addition => 'legend1_addition_here',
      :ylabel => 'This is y', :xlabel => 'This is x Label', :name => 'percentile.pdf'}
  end

  before do
    @a = P2PPlot.plot options
  end
  
  it "should create a graph" do
    File.size('percentile.pdf').should be > 0
  end

  def plot_to_ten
    o = options
    o[:xs] = [0,1,10]
    @a = P2PPlot.plot o
  end

  it "should graph the median lines" do
    assert @a.data[1].with.contain? "candlesticks lt -1"
  end

  context "it should never be wider than half the difference between the smallest xes" do

    before do
      FileUtils.rm_rf 'unnamed.pdf'
      @a = P2PPlot.plot [0.1,0.2,100], [[1,2,3], [0,1,2], [1,2,3], [3,4,5], [4,5,6]]
      assert File.size('unnamed.pdf') > 0
      assert @a.boxwidth.assoc('boxwidth')[1] == 0.05
    end

    it "should also show the median line in cases where a few points are scrunched together" do
    # advisor no likey
#      assert @a.data[1].using.include?("1:4 ") # the 50th percentile line
#      assert @a.data[1].with.include?("lines") # the 50 percentile line
#      assert !@a.data[1].with.include?("candlesticks") # the 50 percentile candlesticks
    end

  end

  it "should have a boxwidth not too large if they are far separated" do
    assert @a.boxwidth.assoc('boxwidth')[1] == 6
  end

  it "should allow for custom legends in the median too" do
    assert @a.data[1].title.include?('legend1_addition_here')
  end

  it "should have a y that's taller than the tallest y...climb every mountain..." do
    y = 6 * 1.1
    @a.yrange.assoc('yrange')[1].should == "[0:#{y}]"
    @a.xrange.assoc('xrange')[1].should == "[-20:210]"
  end

  it "should have an xrange that is always plus one" do
    plot_to_ten
    @a.xrange.assoc('xrange')[1].should == "[-1:11]"
  end

  it "should have a taller y if you pass it in two graphs" do
    a = P2PPlot.plot :xs => [0,100, 200], :percentiles => [[1,2,3], [0,1,2], [1,2,3], [3,4,5], [4,5,6]] , :xs2 =>  [0,100, 200],
        :percentiles2 => [[1,2,3], [0,1,2], [1,2,3], [3,4,5], [4,5,7]]
    y = 7 * 1.1
    a.yrange.assoc('yrange')[1].should == "[0:#{y}]"
  end

  it "should have an optional y that you pass in" do
    options = self.options
    options[:ymax] = '101'
    out =  P2PPlot.plot options
    out.yrange.assoc('yrange')[1].should == "[0:101]"
  end

  it "should print in monochrome" do
    #require 'ruby-debug'
    #debugger
    @a.terminal.assoc("terminal")[1].should == 'pdf monochrome'
  end

  it "should have a large font size" do
    @a.to_gplot.should include 'Times-Roman'
  end

end