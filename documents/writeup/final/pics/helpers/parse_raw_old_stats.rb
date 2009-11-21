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

# this one just parses out the file
# into something like
# {'download times' => {25.0 => [61.51, 161.8, 352.64, 560.03, 992.02]}...}
def parse large_string
  setting = nil
  name = nil
  numbers = nil

  number_regex = '(\d+\.\d+|\d+) '
  five_numbers = Regexp.new((number_regex * 5).strip)
  all = {}

  large_string.each_line {|line|
    if line =~ /_at(\d+)_/
      setting = $1.to_f
    elsif line =~ /iles/ || line =~ /^dht / # percentiles or %'iles' or 'dht xxxx'
      name = line.strip
    elsif line =~ five_numbers
      numbers = [$1.to_f, $2.to_f, $3.to_f, $4.to_f, $5.to_f]
    else
      puts 'ignoring line', line
    end
    if name and setting and numbers
      puts "adding", 'line', line, 'name', name, 'setting', setting, 'numbers', numbers if $VERBOSE
      all[name] ||= {}
      all[name][setting] = numbers
      numbers = nil
    end

  }
  puts 'returning', all.keys.inspect
  all

end

if $0 == __FILE__
  require File.dirname(__FILE__) + '/gnuplot_percentiles'
  require 'rubygems'
  require 'sane'
  puts 'syntax: raw file name1 [raw file name2 if you want comparison...]'
  raise unless ARGV[0] && !ARGV[0].in?(['--help', '-h'])

  x = 'Peers per Second' # this one depends on the directory you're in, I guess [TODO make command line?]


  all = parse File.read(ARGV[0])
  if ARGV[1]
    all2 = parse(File.read(ARGV[1]))
  else
    all2 = {}
  end
  
  for name, y_and_this_output_filename in {
    "download times %'iles'" => ['Peer Download Times (seconds)', 'client_download_Percentile_Line'],
    "server upload [received] distinct seconds [instantaneous server upload per second] %'iles'" => ['Server Upload Speed (Bytes/S)', 'server_speed_Percentile_Line'],
    # server upload is changed for some reason in newer stuffs
    "server upload distinct seconds [instantaneous server upload per second] %'iles'" => ['Server Upload Speed (Bytes/S)', 'server_speed_Percentile_Line'],
    "upload bytes %'iles'" => ['Peer Bytes Uploaded (Bytes)', 'upload bytes'],
    "instantaneous tenth of second throughput %'iles'" => ['Total ThroughPut (Bytes/S)', 'total throughput'],
    'dht removes' => ['DHT Remove Times (S)', 'dht_Remove_Percentile_Line'],
    "percentiles of percent received from just peers (not origin)" => ['Percent of File received from Peers', 'percent_from_clients_Percentile_Line']} do

    y, this_output_filename = y_and_this_output_filename

    data1 = all.delete name
    data2 = all2.delete(name)
    next unless data1

    puts 'got', name, y, this_output_filename if $VERBOSE

    # we have already to split it into lines
    # like
    # 1 10 20 30 40 50
    # 2 10 20 30 40 50
    # => [1, 2], [10, 10], [20, 20]..
    # so now map it to what gnuplot expects...
    xss = []
    columnss = []
    for data in [data1, data2]
      next unless data
      xss << data.sort.map(:first) # the easy one
      columns = []
      data.sort.map(:last).each{ |row|
        row.each_with_index{|setting, i|
          columns[i] ||= []
          columns[i] << setting
        }
      }
      columnss << columns
    end
    puts "plotting", xss.inspect, columnss.inspect, "to", this_output_filename
    P2PPlot.plot xss[0], columnss[0], this_output_filename + '.pdf', x, y, :xs2 => xss[1], :percentiles2 => columnss[1]

  end
  puts 'remain', all.keys.inspect, "\n\n\n"
end
