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

# also ruby parse_raw_old_stats.rb ..\vr_multiples_take_1\number_stats_smaller.txt ..\vr_unnamed937328_multiple_files_cs\number_stats.txt "p2p" "cs"

