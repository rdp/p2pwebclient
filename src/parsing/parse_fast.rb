

class ParseFast

  def initialize filename
    @filename = filename
  end

  # currently returns full download time
  #
  # let's return a hash, like
  # {:download_time => [float or nil], :peer_bytes => x, :origin_bytes => y}
  #
  def go
    @start_regex = /(#{float}).*starting up logger/
    @end_regex = /(#{float}).*DONE WITH WHOLE FILE/

    @cs_straight = /#{float}.*cs straight.*just received (\d+)B/

    @bytes = [[cs_straight, :cs_straight]]

    @starty = nil
    @endy = nil
    @stats = {}
    @stats[:cs_straight] = 0
    @stats[:cs_p2p] = 0


    File.read(@filename).lines {|line|

      if !starty && line =~ start_regex
        puts line, 'start line' if $VERBOSE
        starty = $1.to_f
      else
        begin # pesky encoding errors
          if !endy && line =~ end_regex
            puts line if $VERBOSE
            endy = $1.to_f
          else
                _dbg
            for regex, name in bytes
               if line =~ regex
                   puts 'victory!'
                   @stats[name] += $1
                   break # somewhat helpful...
               end
            end
          end
        rescue => e # encoding error...
          puts line, line.inspect
        end
      end
    }

    @stats[:download_time] = if endy && starty
      puts endy - starty
      endy - starty
    else
      nil
    end

    @stats[:all_cs_bytes] = @stats[:cs_straight] + @stats[:cs_p2p]

    @stats
  end

  def parse_line line


  end

end

if __FILE__ == $0
  puts ParseFast.new(ARGV[0]).go
end
