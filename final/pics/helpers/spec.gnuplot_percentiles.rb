require 'sane'
require_relative 'gnuplot_percentiles.rb'
require 'spec/autorun'

describe P2PPlot do

  it "should be able to take a hahs and calculate minimum x values from it as if it were graph lines" do
    P2PPlot.get_smallest_x({'abc' => [[1,1], [1,2]]}).should == 1
  end

  it "should generate a graph" do
    File.delete 'name.pdf' if File.exist? 'name.pdf'
    P2PPlot.plotNormal 'x label', 'y label', {'abc' => [[1,1], [2,2], [3,3]]}, 'name.pdf'
    assert File.exist? 'name.pdf'
  end
  
  before do
    @a = P2PPlot.plot [0,100, 200], [[1,2,3], [0,1,2], [1,2,3], [3,4,5], [4,5,6]] 
  end
  
  it "should graph the median lines" do
    assert @a.data[1].with == "candlesticks lt -1"  
  end
  
  it "should never be wider than half the difference between the smallest xes" do
    a = P2PPlot.plot [0.1,0.2,100], [[1,2,3], [0,1,2], [1,2,3], [3,4,5], [4,5,6]] 
    assert a.boxwidth.assoc('boxwidth')[1] == 0.05
  end
  
  it "should have a boxwidth not too large if they are far separated" do
    assert @a.boxwidth.assoc('boxwidth')[1] == 6
  end
  
  it "should allow for custom legends"
  

end
