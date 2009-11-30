require 'sane'
for dir in Dir['../*'] do
 if File.directory? dir
   Dir.chdir(dir) {
     stats_file = Dir['number_stats*'][0]
     if stats_file
       type = 'Load (Peers per Second)'
       mapping = {'do_dts' => 'T (s)', 'blockSize' => 'BlockSize (B)',
              'vary_blocks' => 'Peer Connection Limit'}
       for key, y in mapping
          if dir.include? key
             type = y
          end
       end
       command = "ruby ..\\helpers\\parse_raw_old_stats.rb #{stats_file} \"#{type}\""
       system command
       print dir, command, "\n"
     else
       puts 'no stats found?', dir
     end

   }

 end
end

