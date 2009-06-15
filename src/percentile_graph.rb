require 'new_graphs.rb'
require 'graphHelpers.rb'

# yuck yuck yucky this should inherit from Gruff!

class PercentileGraph

def initialize(arrayOfPercentileValuesWeWillBeHaving = [25,50,75])
  @arrayToHoldEachPercentile = []
  @percentileValues = arrayOfPercentileValuesWeWillBeHaving # keep a copy so we can remember it for the legend...
  @data = ['Percentiles', []]
end

def nextPoint(xIndex, arrayToMatchPercentiles)
  @data[1] << [xIndex, arrayToMatchPercentiles]
end

  def generate(toThisFile, title = "fake title", yLabel = "fake y", xAxisLabel = "varying the x axis") # ltodo combine?
    # ltodo update this to...just be better (?) maybe use the old one as a template. ah well :)
    GraphHelper.createToFileMultipleLinesWithPercentileArray(toThisFile, title, yLabel, xAxisLabel, [@data], @percentileValues, nil, true, true)
  end
# ltodo double check skipping localhost

#vltodo vary server speed from 10000 to 10020 -- goes down barely vary_serverBpS_from_10000by_20_1_times_2s_10_3s_20000B_10000BPS_7000s_0.01s_5.0s_5000B  
def PercentileGraph.testSelf
 require 'ruby-debug'; Debugger.start
 subject = PercentileGraph.new([25,50,75])
 subject.nextPoint(0, [0,0,0])
 subject.nextPoint(1, [1,2,3])
 subject.nextPoint(1.5, [0.5, 2.5, 4])
 subject.generate("test/percentile_test.png")

 subject = PercentileGraph.new([1,25,50,75,99])
 subject.nextPoint(0, [0, 0, 0, 0, 0])
 subject.nextPoint(1, [0.1, 1, 2, 3, 3.5])
 subject.nextPoint(2, [0,0.5, 2.5, 4, 10])
 subject.generate("test/percentile_test_big.png")

 subject = PercentileGraph.new([1,25,50,75,99])
 subject.nextPoint(0, [0, 0, 0, 0, 0])
 subject.nextPoint(1, [0.1, 1, 2, 3, 3.5])
 subject.nextPoint(2, [0,0.5, 2.5, 4, 10])
 subject.generate("test/percentile_test_big.png")



end

end

if runOrRunDebug?(__FILE__)
   PercentileGraph.testSelf
end