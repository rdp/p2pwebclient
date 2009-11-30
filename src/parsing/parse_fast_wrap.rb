require 'sane'
require_rel 'parse_fast.rb'

class Array
  def ave
    sum = 0
    self.each{|item| sum += item}
    return sum.to_f/length
  end
end

#name = 'unnamed316651'
#runs = [6, 15, 20, 25]
#
name = 'yanc_30mb_3'
runs = ['false']

all_clients = []

begin
for run in runs do
  all = Dir["**/#{name}*_at#{run}_run*/*"]
  puts 'got length for this run...', all.length
  all.each{|f| 
    puts f
    all_clients << ParseFast.new(f).go
  }
end
ensure
puts all_clients, all_clients.inspect
end
