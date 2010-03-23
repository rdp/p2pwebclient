# this one just parses out the file
# into something like
# {'download times' => {25.0 => [61.51, 161.8, 352.64, 560.03, 992.02]}...}
#require 'faster_require'
require 'sane'
require_relative 'gnuplot_percentiles'

class Parser
  def self.parse large_string
    setting = nil
    name = nil
    numbers = nil

    number_regex = '(\d+\.\d+|\d+) '
    five_numbers = Regexp.new((number_regex * 5).strip)
    all = {}

    float_or_int = /\d+\.?\d*/

    large_string.each_line { |line|

      # identify which type of line we're on
      # and process it if we've got all the info we need
      # state machine-y

      if line =~ /_at(#{float_or_int})_/
        setting = $1.to_f
      elsif line =~ /iles/ || line =~ /^dht / # percentiles or %'iles' or 'dht xxxx'
        name = line.strip
      elsif line =~ five_numbers
        numbers = [$1.to_f, $2.to_f, $3.to_f, $4.to_f, $5.to_f]
      elsif line =~ /death methods/
        name = 'death methods'
      elsif (scans = line.scan /(\S+) (\d+\.\d+)/).length > 0 # like died 1234.0
        hash = {}
        scans.each{|death_type, value| hash[death_type] = value.to_f }
        numbers = hash
      else
        puts 'ignoring line', line if $VERBOSE
      end

      if name and setting and numbers # setting changes rarely
        puts "adding", 'line', line, 'name', name, 'setting', setting, 'numbers', numbers if $VERBOSE
        all[name] ||= {}
        all[name][setting] = numbers
        numbers = nil
      end
    }

    puts 'returning successfully parsed', all.keys.inspect
    all
  end
end



class ParseRaw

  # we've got
  #{1.0=>{"dR"=>0.0, "dT" =>
  # and we want something like
  #P2PPlot.plotNormal 'x label', 'y label', {'abc' => [[1,1], [2,2], [3,3]]}, 'name.pdf'
  def self.translate_conglom_hashes_to_lined_hashes data1
    xs = data1.keys
    first_member = data1[xs[0]]

    all_data = {}

    first_member.each_key{|dr|
      all_data[dr] = []
    }

    # now all_data is {'dr' => [], 'dt' => [] ...}
    data1.each{|x, all_settings|
      all_data.each_key{|setting|
        all_data[setting] << [x, all_settings[setting]]
      }

    }

    all_data
  end

  def self.go file1, x = 'Load (Peers per Second)', file2 = nil, legend1 = nil, legend2 = nil

    require 'rubygems' if RUBY_VERSION < '1.9'
    require 'sane'
    out = []
    all = Parser.parse File.read(file1)
    if file2
      all2 = Parser.parse(File.read(file2))
    else
      all2 = {}
    end

    for name, (y, this_output_filename) in {
      "download times %'iles'" => ['Client Download Time (seconds)', 'client_download_Percentile_Line'],
      "download total times %'iles'" => ['Peer Download Times All files (seconds)', 'client_download_all_files_Percentile_Line'],
      "server upload [received] distinct seconds [instantaneous server upload per second] %'iles'" => ['Server Upload Speed (Bytes/s)', 'server_speed_Percentile_Line'],
      # server upload is changed for some reason in newer stuffs
      "server upload distinct seconds [instantaneous server upload per second] %'iles'" => ['Server Upload Speed (Bytes/s)', 'server_speed_Percentile_Line'],
      "upload bytes %'iles'" => ['Peer Bytes Uploaded (Bytes)', 'upload bytes'],
      "instantaneous tenth of second throughput %'iles'" => ['Total ThroughPut (Bytes/s)', 'total throughput'],
      'dht removes' => ['DHT Removal Time (S)', 'dht_Remove_Percentile_Line'],
      'dht puts' => ['DHT Set Time (S)', 'dht_Put_Percentile_Line'],
      'dht gets' => ['DHT Set Time (S)', 'dht_get_Percentile_Line'],
      'death methods' => ['Number of peers', 'death_reasons'],
      "percentiles of percent received from just peers (not origin)" => ['Percent of File received from Peers', 'percent_from_clients_Percentile_Line']} do

      data1 = all.delete name
      data2 = all2.delete(name)
      next unless data1

      puts 'got', name, y, this_output_filename if $VERBOSE
      if name =~ /percentiles of percent/
        # multiply by 100
        data1.each{|k, v| data1[k] = v.map{|old_number| old_number*100} }
        data2.each{|k, v| data1[k] = v.map{|old_number| old_number*100} } if data2
      end
      
      # special case the single line graphs...
      if name == 'death methods'
        # do some renames, too
        map = {'dR' => 'R', 'dT' => 'T', 'http_straight' => 'Origin', 'died' => 'Failed'}
        data1_mapped = {}
        data1.each{|second, values|
          values_mapped = {}
          sum = 0
          values.each{|name, value| sum += value}
          values.each{|name, value|
            new_name = map[name]
            raise name unless new_name
            values_mapped[new_name] = value*100/sum
          }
          data1_mapped[second] = values_mapped
        }
        data = ParseRaw.translate_conglom_hashes_to_lined_hashes data1_mapped
        out << (P2PPlot.plotNormal x, y, data, this_output_filename + '.pdf')
      else

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
          xss << data.sort.map_by(:first) # the easy one
          columns = []
          data.sort.map_by(:last).each{ |row|
            row.each_with_index{|setting, i|
              columns[i] ||= []
              columns[i] << setting
            }
          }
          columnss << columns
        end
        ymax = nil
        if name =~ /download times/
          unless columnss.map(&:last).max.max > 450 # allow for the huge test to have its own
            ymax = 180
          end
        end 
        
        if name =~ /server upload/          
          ymax = 400_000
        end        
          
        puts "percentile plotting", xss.inspect, columnss.inspect, "to", this_output_filename if $VERBOSE
        out << P2PPlot.plot(xss[0], columnss[0], this_output_filename + '.pdf', x, y, :xs2 => xss[1], :percentiles2 => columnss[1], :legend1_addition => legend1, :legend2_addition => legend2, :ymax => ymax)        
      end

    end
    puts 'keys never used:', all.keys.inspect, "\n\n\n"
    out
  end

end

if $0 == __FILE__
  puts '(always displayed) syntax: raw file name1 [raw file name2 if you want comparison...] "dT (s)"'
  puts 'generates files like server_speed_Percentile_line.pdf in the local dir, using gnuplot'
  raise unless ARGV[0] && !ARGV[0].in?(['--help', '-h'])

  # so lazy
  if ARGV[1]
    if File.exist? ARGV[1]
      puts 'doing dual file...'
      assert ARGV.length >= 2
      ParseRaw.go ARGV[0], 'Load (peers per second)', ARGV[1], ARGV[2], ARGV[3] # dual file mode, with legend names
    else
      ParseRaw.go ARGV[0], ARGV[1] || 'Peers Per Second' # "specify y axis" mode
    end
  else
    ParseRaw.go ARGV[0]
  end
end
