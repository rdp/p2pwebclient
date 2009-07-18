require 'rubygems_f'
require 'sane'
require_rel 'gnuplot_percentiles'

def do_file filename, xlabel = nil, ylabel = nil
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

  P2PPlot.plot xs, percentiles, xlabel, ylabel

end

module DBChecker extend OptiFlagSet
  optional_flag "file"
  optional_flag "dir"

  and_process!
end

do_file ARGV.flags.file if ARGV.flags.file

if ARGV.flags.dir
  raise 'no implemented'
end
