def require_relative glob # we don't allow for requiring directories currently :)
  dir = File.dirname(caller[0]) + '/'
  puts 'dir is', dir
  for file in Dir[dir + glob]
   require file
  end
end

def println *args
 print *args
 puts
end

require_relative '*'

=begin rdoc
doctest: loads from subdir
>> dir = Dir.pwd
>> Dir.chdir('..') do; require dir + "/test_sane/load"; end
>> $here
=> 1
=end