require 'forky'
module Enumerable
  def forky
    self.length.times { yield }
  end
end


