class HashSetOperators
  VERSION = '0.1.0'
end

class Hash
  # Returns a new hash containing both the contents of the first hash
  # and the second.  In cases where the same key is present in both
  # hashes, the values from the second are retained and not the
  # first.
  #
  # It is essentially an alias for Hash#merge
  #
  #   {:a => 1, :b => 2} + {:c => 3}
  #   # => {:a => 1, :b => 2, :c => 3}
  #
  #   {:a => 1, :b => 2} + {:a => 3}
  #   # => {:a => 3, :b => 2}
  #
  alias :+ :merge

  # Hash difference returns a new hash that is a copy of the original 
  # removing any keys that also appear in the second hash.
  # 
  #   {:a => 1, :b => 2} - {:b => 3}
  #   # => {:a => 1}
  #
  def -(hash)
    hash.keys.each do |key|
      delete key
    end
    self
  end

  # Returns a new hash that is a copy of the original, removing any
  # keys that do not appear in the second hash.
  # 
  #   {:a => 1, :b => 2} & {:b => 3}
  #   # => {:b => 2}
  #
  def &(hash)
    (keys - hash.keys).each do |key|
      delete key
    end
    self
  end
end
