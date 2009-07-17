# doesn't work with implicit .rb yet...
# require 'require_all'


# requires files relative to the current file
# a la require_rel 'lib/abc'	  
# currently accepts either a glob [something with * in it]
# or a full filename, like require
def require_rel glob # we don't allow for requiring directories currently :)
  dir = File.dirname(caller[0]) + '/' # their __DIR__
  if glob.include? '*'
    files = Dir[dir + glob]
  else
    files = [dir + glob]
  end
  for file in files
   if(!File.exist?(file) && File.exist?(file + '.rb'))
    require file + '.rb'
   else
    require file
   end
  end
end


# prints output with a carriage return
def println *args
 print *args
 puts
end

=begin rdoc

doctest: loads from subdir with a full name
>> dir = Dir.pwd
>> Dir.chdir('..') do; require dir + "/test_sane/load"; end
>> $here
=> 1

doctest: Also,  like a normal require, you can leave off the .rb suffix
>> Dir.chdir('..') do; require dir + "/test_sane/load2"; end 
>> $here2
=> 1

=end

class Object
  def in? collection
    collection.include? self
  end
end

require_rel 'enumerable-extra' # for 1.9 compat.
