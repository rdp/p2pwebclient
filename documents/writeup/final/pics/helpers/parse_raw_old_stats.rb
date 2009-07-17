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
  require File.dirname(__FILE__) + '/sane/sane'
  puts 'syntax: raw file name'
  raise unless ARGV[0]
  all = parse File.read(ARGV[0]) # output is currently like
  #  {'download times' => {25.0 => [61.51, 161.8, 352.64, 560.03, 992.02]}...}


  x = 'Peers per Second' # this one depends on the directory you're in, I guess [TODO make command line?]

["percentiles of percent received from just peers (not origin)", "upload bytes %'iles'", "server upload distinct seconds [instantaneous server upload per second] %'iles'", "download times %'iles'", "instantaneous tenth of second throughput %'iles'"]


  for name, y_and_this_output_filename in {"download times %'iles'" => ['seconds', 'client_download_Percentile_Line'], 
     "server upload [received] distinct seconds [instantaneous server upload per second] %'iles'" => ['Bytes/S', 'server_speed_Percentile_Line'],  

     # server upload is duplicated for some reason in newer stuffs

     "server upload distinct seconds [instantaneous server upload per second] %'iles'" => ['Bytes/S', 'server_speed_Percentile_Line'],  
     "upload bytes %'iles'" => ['Bytes/S', 'upload bytes'], 
     "instantaneous tenth of second throughput %'iles'" => ['Bytes/S', 'total throughput'],
     'dht removes' => ['S', 'dht_Remove_Percentile_Line'],
     "percentiles of percent received from just peers (not origin)" => ['% of File', 'percent_from_clients_Percentile_Line']} do

    y, this_output_filename = y_and_this_output_filename
    data = all.delete name
    next unless data

    puts 'got', name, y, this_output_filename if $VERBOSE

    # we have to split it into lines
    # like
    # 1 10 20 30 40 50
    # 2 10 20 30 40 50
    # => [1, 2], [10, 10], [20, 20]..
    xs = data.sort.map :first # the easy one
    columns = []
    data.sort.map(:last).each{ |row|
      row.each_with_index{|setting, i|
        columns[i] ||= []
        columns[i] << setting
      }
    }
    puts "plotting", xs.inspect, columns.inspect, "to", this_output_filename 
    plot xs, columns, this_output_filename + '.pdf', x, y
  end
  puts 'remain', all.keys.inspect, "\n\n\n"
end
