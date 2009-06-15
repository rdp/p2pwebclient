# forkoff makes it trivial to do parallel processing with ruby, the following
# prints out each word in a separate process
#

  require 'forkoff'

  results = %w( hey you ).forkoff!{|word| puts "#{ word } from #{ Process.pid }"; 3}
  p results
