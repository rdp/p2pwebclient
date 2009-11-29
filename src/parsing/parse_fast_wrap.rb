require 'go.rb'
class Array
  def ave
    sum = 0
    self.each{|item| sum += item}
    return sum.to_f/length
  end
end

name = 'unnamed316651'
global = {}
for run in [6, 15, 20, 25] do
  all = Dir["**/#{name}_at#{run}_run*/*"]
  puts 'got all', all.length
  # I'm looking for average...
  output = []
  all.each{|f| puts f; output << go(f)}
  output.compact!
  puts output.ave
  global[run] = output.ave
end
puts global
