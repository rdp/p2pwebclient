for dir in Dir['../*'] do
 if File.directory? dir
   Dir.chdir( dir) {
     stats = Dir['number_stats*'][0]
     if stats
       system("ruby ..\\helpers\\parse_raw_old_stats.rb #{stats}")
     else
       puts 'no stats?', dir
     end

   }

 end
end

