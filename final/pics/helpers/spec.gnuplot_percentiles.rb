require 'sane'
require_relative 'gnuplot_percentiles.rb'
require 'spec/autorun'

describe P2PPlot do

  it "should be able to take a hahs and calculate minimum x values from it as if it were graph lines" do
    P2PPlot.get_smallest_x({'abc' => [[1,1], [1,2]]}).should == 1
  end

  def plot_single
    File.delete 'test.pdf' if File.exist? 'test.pdf'
    P2PPlot.plotNormal 'x label', 'y label', {'abc' => [[1,1], [2,2], [3,3]]}, 'test.pdf'
  end
  
  it "should generate a straight line graph too" do
    plot_single
    assert File.exist? 'test.pdf'
  end
  
  before do
    @a = P2PPlot.plot [0,100, 200], [[1,2,3], [0,1,2], [1,2,3], [3,4,5], [4,5,6]], :legend1_addition => 'legend1_addition_here'
  end
  
  it "should graph the median lines" do
    assert @a.data[1].with.contain? "candlesticks lt -1"  
  end
  
  it "should never be wider than half the difference between the smallest xes" do
    a = P2PPlot.plot [0.1,0.2,100], [[1,2,3], [0,1,2], [1,2,3], [3,4,5], [4,5,6]] 
    assert a.boxwidth.assoc('boxwidth')[1] == 0.05
  end
  
  it "should have a boxwidth not too large if they are far separated" do
    assert @a.boxwidth.assoc('boxwidth')[1] == 6
  end
  
  it "should allow for custom legends in the median too" do
     assert @a.data[1].with.include?('legend1_addition_here')
  end
  
  it "should have a y that's taller than the tallest y...climb every mountain..." do
    y = 6 * 1.1
    @a.yrange.assoc('yrange')[1].should == "[0:#{y}]"    
  end
  
  it "should have a taller y if you pass it in two graphs" do
    a = P2PPlot.plot :xs => [0,100, 200], :percentiles => [[1,2,3], [0,1,2], [1,2,3], [3,4,5], [4,5,6]] , :xs2 =>  [0,100, 200], :percentiles2 => [[1,2,3], [0,1,2], [1,2,3], [3,4,5], [4,5,7]]
    y = 7 * 1.1
    a.yrange.assoc('yrange')[1].should == "[0:#{y}]"
  end
  
  
  it "should have a tall y for single line graphs, too" do
    a = plot_single
    y = 3*1.1
    a.yrange.assoc('yrange')[1].should == "[0:#{y}]"
  end

end
