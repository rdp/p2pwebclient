

class ParseFast

  def initialize filename
    @filename = filename
  end

  # currently returns full download time
  #
  # let's return a hash, like
  # {:download_time => [float or nil], :peer_bytes => x, :origin_bytes => y}
  #
  def go use_this_test_string = nil
    float = /\d+\.\d+/
    start_regex = /(#{float}).*starting up logger/
    end_regex = /(#{float}).*DONE WITH WHOLE FILE/

    cs_straight = /#{float}.*cs straight.*just received (\d+)B/

    p2p_p2p =/p2p p2p.*just received (\d+)B/ 
    cs_p2p = /p2p cs.*just received (\d+)B/

    bytes = [[cs_straight, :cs_straight], [p2p_p2p, :p2p_p2p], [cs_p2p, :cs_p2p]]

    starty = nil
    endy = nil
    stats = {}

    bytes.each{|regex, name|
     stats[name] = 0
    }

    (use_this_test_string || File.read(@filename)).lines {|line|

      if !starty && line =~ start_regex
        puts line, 'start line' if $VERBOSE
        starty = $1.to_f
      else
        begin # pesky encoding errors
          if !endy && line =~ end_regex
            puts line if $VERBOSE
            endy = $1.to_f
          else
            for regex, name in bytes
              if line =~ regex
                stats[name] += $1.to_i
                break # somewhat helpful...
              end
            end
          end
        rescue => e # encoding error...
          puts line, line.inspect
        end
      end
    }

    stats[:download_time] = if endy && starty
      puts endy - starty
      endy - starty
    else
      nil
    end

    stats[:all_cs_bytes] = stats[:cs_straight] + stats[:cs_p2p]

    stats
  end

end

if __FILE__ == $0
puts ParseFast.new(ARGV[0]).go
end
