=begin
doctest: parses a conjunto right
>> all = "Doing stats on runs runs just numbers unnamed316651_at25_run1unnamed316651_at25_run2\ndownload times %'iles'\n61.51 161.8 352.64 560.03 992.02"
>> parse(all)
=> {'download times' => {25.0 => [61.51, 161.8, 352.64, 560.03, 992.02]}}
>> parse( File.read 'test/single_run.txt')['download times'] == {25.0 => [61.51, 161.8, 352.64, 560.03, 992.02]}
=> true
>> parse( File.read 'test/single_run.txt')['server upload distinct seconds [instantaneous server upload per second]'] == {25.0 => [37565.0, 126882.5, 181103.5, 243156.5, 458349.5]}
=> true
=end


def parse large_string
   setting = nil
   name = nil
   numbers = nil

   number_regex = '(\d+\.\d+|\d+) '
   five_numbers = Regexp.new((number_regex * 5).strip)
   all = {}

   large_string.each_line {|line|
      puts 'processing line', line
      if line =~ /_at(\d+)_/
         setting = $1.to_f
      elsif line =~ /(^.*) %'iles'/ # percentiles
         name = $1
      elsif line =~ five_numbers
         puts 'got good'
         numbers = [$1.to_f, $2.to_f, $3.to_f, $4.to_f, $5.to_f]
      end

      puts "\n\n\n", 'line', line, 'name', name, 'setting', setting, 'numbers', numbers
      if name and setting and numbers
         all[name] ||= {}
         all[name][setting] = numbers
         numbers = nil
      end

   }
   all

end

if $0 == __FILE__
  require 'gnuplot_percentiles'
  require 'rubygems'
  require 'enumerable/extra'
  puts 'syntax: raw file name'
  raise unless ARGV[0]
  output = parse File.read(ARGV[0]) # output is like 
  #  {'download times' => {25.0 => [61.51, 161.8, 352.64, 560.03, 992.02]}}
  download = output['download times']
  xs = download.sort.map :first
  percentiles = download.sort.map :last
  p download, 'was download', 'xs', xs, 'percentiles', percentiles
  plot xs, percentiles, 'x', 'y'
end
