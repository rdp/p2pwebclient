require 'sane'
for dir in Dir['../*'] do
 if File.directory? dir
   Dir.chdir(dir) {
     stats_file = Dir['number_stats*'][0]
     if stats_file
       type = 'Load (Peers per Second)'
       mapping = {'17712_dT' => 'T (s)', 'blockSize' => 'BlockSize (B)',
              'vary_blocks' => 'Peer Connection Limit', '_dw' => 'W (s)',
              'vr_unnamed502788_dR' => 'R (bytes/s)',
              'unnamed497104_linger' => 'Lingering time (seconds)'}
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

system "ruby cdf_yanc_30.rb"

Dir.chdir '../multiples_p2p_versus_cs_pics' do
   # remake these, too
#   system 'ruby ../helpers/parse_raw_old_stats.rb ..\vr_multiples_take_1\number_stats_smaller.txt ..\vr_unnamed937328_multiple_files_cs\number_stats.txt "p2p" "cs"'
   system 'ruby ../helpers/parse_raw_old_stats.rb ..\vr_multiples_take_1\number_stats_smaller.txt ..\vr_unnamed937328_multiple_files_cs\number_stats.txt'

end

