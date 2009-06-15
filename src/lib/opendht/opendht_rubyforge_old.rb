require 'lib/ruby_useful_here'
#useMultiHomed
# opendht.rb -- a Ruby OpenDHT access implementation
#
# (C) 2006, John Russell Lane, SORA Project, The University of Tokyo
# ltodo puts have weird string
# This is free software; you may redistribute it and/or modify it
# under the terms of the GNU General Public License as published by the
# Free Software Foundation; either version 2, or (at your option) any
# later version.  No warantee or guarantee is expressed or implied; use of
# your own volition, at your own risk.
#
# Simple synopsis:
#
#   require 'opendht'
#   dht = OpenDHT::Hash.new
#   dht['favorite color'] = 'blue'
#   puts 'Favorite color: ' + dht['favorite color']
# 
# Slightly more complicated synopsis:
#
#   require 'opendht'
#   dht = OpenDHT::Hash.new
#   dht['motd'] = 'this is one message; there could be others'
#   # ... somewhere else ... 
#   dht['motd'] = File.read('/etc/motd')
#   # ... somewhere else ... 
#   dht.get('motd').each { |keyval| puts keyval.key + ' sez ' + keyval.value }
#
# Or another:
#
#   require 'opendht'
#   dht = OpenDHT::Hash.new
#   kv = OpenDHT::SerialKeyValue.new('scores', 'New York 3, Tokyo 3')
#   kv.serial = Time.now.utc.tv_sec
#   kv.ttl = 60 * 60 * 3
#   dht.put(kv)
#   # ...
#   kv = OpenDHT::SerialKeyValue.new('scores', 'New York 4, Tokyo 3')
#   kv.serial = Time.now.utc.tv_sec + 600
#   kv.ttl = 60 * 60 * 3
#   dht.put(kv)
#   # ...
#   kvs = dht.get(OpenDHT::SerialKeyValue.new('scores'))
#   kvs.each_serial { |time|
#     puts 'Time: ' + Time.at(time).to_s
#     kvs[time].each { |kv| puts "\t" + kv.value }
#   }
#
# --
#
# First, see: http://www.opendht.org/
#
# Now, OpenDHT provides an abstraction atop what is normally exported and
# makes it a little easier to deal with.  It automatically uses SHA-1 for
# hashing keys, allows
# the use of values longer than 1024 bytes (by splitting a value over
# multiple put()'s) and can perform key-match verification on get().
# Finally, it also makes it easier to cope with multiple values returned from a
# get() by returning a iterable / array-indexable (multi-value) object.
#
# It does this, in part, by providing three basic access classes.
# In the simplest 
# (KeyValue) values are limited to 1024-bytes, though multiple values are
# returned (up to a configurable maximum -- all by default).
# A more complex form
# (ExtendedKeyValue) provides for splitting values over multiple put()'s
# as well as key checking and multiple value retrieval.
# A third (SerialKeyValue) is likely only of use to a few but adds
# the ability to store and retrieve multiple values for a given key using
# a (four byte) serial number (e.g., a timetstamp).  Note that this is simply
# an extension of the above (ExtendedKeyValue).
#
# The multiple value classes of the above are known as KeyValues,
# ExtendedKeyValues and SerialKeyValues respectively.
#
# Several more features exist (e.g., an automatic key prefixer).
# See the API/code for details.

require 'digest/sha1'
require 'xmlrpc/client'
require 'pp'
require 'rexml/document' # attempt to avoid some loading bugs

class String
  def to_sha
    d = Digest::SHA1.new
    d << self
    d.digest
  end
  def to_xmlrpc_base64()   
    
    out = XMLRPC::Base64.new(self, :dec); 
    assert out.decoded
    return out
  end
  
  def from_xmlrpc_base64() 
    out = XMLRPC::Base64.new(self, :enc); 
    assert out.decoded
    return out
  end
  def to_hex() self.unpack('H*')[0]; end
end

class Array
 def sliceOffFrontAndPutAtBackReturnsTwo!(thisMany)
   slicedOut = self.slice!(0,thisMany)
   newSelf = self + slicedOut
   return slicedOut, newSelf
 end
end

class XMLRPC::Base64 # ltodo give to Ruby :)
  def to_s
    assert self, "what no self to do to_s on ?"
    interiorString = self.decoded # might return nil?
    assert interiorString
    return '[' + interiorString + "](base64)"
  end
end


module OpenDHT
  DEFAULT_NUM_RETRIES = 2 # set to 0 for no retrying
  DEFAULT_GATEWAY = 'http://opendht.nyuld.net:5851'
  
  class OpenDHTFailure < RuntimeError; end
  class OverCapacityError < OpenDHTFailure; end
  class TryAgainError     < OpenDHTFailure; end
  
  class KeyValues
    def initialize(key=nil, key_prefix='', key_value_class=KeyValue)
      @key_prefix      = key_prefix
      @key             = key_prefix + key
      @key_value_class = key_value_class
      @values          = []
      @ttls            = []
    end
    # :call-seq:
    #   key(key=nil)
    #
    # If a key is provided, sets the key to the given value; otherwise returns
    # the current key.  (Transparently handles key prefixing.)
    def key(key=nil) # allows transparent use of a key prefix
      if ! key
        @key[@key_prefix.length, @key.length-@key_prefix.length]
      else
        @key = @key_prefix + key
      end
    end
    # :call-seq:
    #   key_prefix(prefix=nil)
    #
    # If a key prefix is provided, sets the key prefix to the given value;
    # otherwise returns the current key prefix.
    # (Transparently handles key prefixing.)
    def key_prefix(key_prefix=nil)
      if key_prefix
        @key_prefix = key_prefix
        @key        = @key_prefix + @key
      end
      @key_prefix
    end
    
    
    
    # :call-seq:
    #   get(curr_val)
    #
    # Returns the KeyValue corresponding to the given index, nil if
    # non-existent.
    def get(num)
      return nil if ! @values[num]
      @key_value_class.new(@key, @values[num])
    end
    # :call-seq:
    #   get_latest
    #
    # Returns the most recently retrieved KeyValue; nil if non-existent.
    def get_latest(num) self.get(-1); end
    # :call-seq:
    #   [](curr_val)
    #
    # Returns the KeyValue corresponding to the
    # given index, nil if non-existent,
    def [](num) self.get(num); end
    # :call-seq:
    #   each()
    #
    # Yields all respective values in the order they were loaded.
    def each
      0.upto(@values.length-1) { |value_no| 
        kv = @key_value_class.new(@key, @values[value_no])
        kv.ttl = @ttls[value_no] if @ttls[value_no]
        yield kv
      }
    end
    # :call-seq:
    #   <<(vlet)
    #
    # Loads the given value-let.
    def <<(value)            self.collect_vlets(value); end
    protected
    def collect_vlets(value) self.collect(value); end
    def collect(value)
      if value.is_a?(Fixnum) ||
        value.is_a?(Bignum): return @ttls[@values.length-1] = value; end
      @values.push(value)
    end
  end
  
  # Allows storage of values of arbitrary length.  Multiple such values per key
  # are returned (should they exist), via array indexing or the each method.
  #
  # get() returns ExtendedKeyValue.new(...)
  class ExtendedKeyValues < KeyValues
    attr_reader :check_keys
    attr_writer :check_keys
    def initialize(key=nil, key_prefix='', kvc=ExtendedKeyValue)
      @curr_val     = -1
      @check_keys   = true
      @vlets        = [ ] # has just the values
      @vlet_totals  = [ ]
      @vlet_ttls    = [ ]
      @vlet_secrets = [ ] # TODO: as yet, unused
      super(key, key_prefix, kvc)
    end
    
    attr_accessor :vlets # I want these :)
    
    def allAsArray
      newArray = []
      for value in @vlets do
        newArray << value[0]
      end
      return newArray
    end
    # :call-seq:
    #   each()
    #
    # Yields all respective values in the order they were loaded.
    def each
      curr_val = 0
      loop do # we may receive only a subset of a values vlets; discard if so
        next if ! (val = @vlets[curr_val])
        num = 0;  v = '';
        val.each { |vlet| v += vlet;  num += 1; }
        if num != @vlet_totals[curr_val]: curr_val += 1; next; end
        kv = @key_value_class.new(@key, v)
        kv.ttl = @vlet_ttls[curr_val] if @vlet_ttls[curr_val]
        yield kv
        break if (curr_val += 1) >= @vlets.size
      end
    end # fails with ['a'] = 'b'; ['a'] = 'c';  dht['a'].each { |keyval| puts 'each'  + keyval.key + keyval.value }
    
    # :call-seq:
    #   get(curr_val)
    #
    # Returns nil if non-existent, the value corresponding to the
    # given index, otherwise.
    def get(curr_val)
      return nil if ! curr_val || ! @vlets[curr_val]
      num = 0;  v = '';
      @vlets[curr_val].each { |vlet| v += vlet;  num += 1; }
      return nil if num != @vlet_totals[curr_val]
      kv = @key_value_class.new(@key, v)
      kv.ttl = @vlet_ttls[curr_val] if @vlet_ttls[curr_val]
      return kv
    end
    # :call-seq:
    #   get_latest
    #
    # Returns the most recent (TTL-wise) value; nil if no values exist.
    def get_latest() 
      if self.latest_ttl
        return self.get(self.latest_ttl[1]); 
      else
        return nil
      end
    end
    # :call-seq:
    #   length
    #
    # Returns the number of values currently stored.
    def length() @vlets.length; end
    # :call-seq:
    #   size
    #
    # Returns the number of values currently stored.
    def size()   @vlets.length; end
    # :call-seq:
    #   latest_ttl
    #
    # Returns an array containing two elements:
    #   0. the latest TTL for the given serial number
    #   1. the array index of the element with the latest TTL
    def latest_ttl
      return nil if @vlet_ttls.size == 0
      ttl = 0;  latest_idx = -1;
      @vlet_ttls.each_index { |idx| 
        next if ! @vlet_ttls[idx]
        if @vlet_ttls[idx] > ttl
          ttl = @vlet_ttls[idx]
          latest_idx = idx
        end
      }
      return nil if latest_idx == -1
      [ttl, latest_idx]
    end
    protected
    def collect_vlets(uvlets)
      # format: see above; @key must be valid for this to work
      if uvlets.is_a?(Array): vlets = uvlets
      else vlets = [uvlets] end
      vlets.each { |vlet| self.unpack_vlet(vlet) }
    end
    def unpack_vlet(vlet) # note that ttls must come *after* their values
      return if ! vlet
      # all numbers that come our way are TTLs
      if vlet.is_a?(Fixnum) || vlet.is_a?(Bignum)
        if @curr_val == -1
          warn('warning: curr_val is unset in unpack_vlet(' + vlet.to_s + ')')
        end
        if (! @vlet_ttls[@curr_val]) ||
         (@vlet_ttls[@curr_val] && (vlet < @vlet_ttls[@curr_val]))
          return @vlet_ttls[@curr_val] = vlet
        else return vlet end
      end
      # anything else (which should be a string) is a vlet
      return if vlet == '' || ! vlet.is_a?(String)
      if @check_keys
        vlet_num, total, key, val = vlet.unpack('CCZ*Z*')
        if @key != key
          #         warn('key mismatch: @key = ' + @key.inspect + '; key: ' + key.inspect)
          return 
        end
      else vlet_num, total,   val = vlet.unpack('CCZ*') end
      return nil if ! val
      if vlet_num == 0: @curr_val += 1 end # requires ordered unpacking
      @vlets[@curr_val] = [ ] if ! @vlets[@curr_val]
      @vlets[@curr_val][vlet_num] = val
      @vlet_totals[@curr_val] = total
      vlet
    end
  end
  
  # This is a factory for SerialKeyValue objects; it also
  # provides
  # a method for holding SerialKeyValue pairs from multiple serial numbers.
  # This is
  # the object into which get()'s are placed, sorted out by serial number and
  # pieced back together.
  class SerialKeyValues < ExtendedKeyValues
    def initialize(key=nil, key_prefix='', kvc=SerialKeyValue)
      @current_unlabeled_serial_num = 0
      @last_sn         = nil
      @sn_vlets        = { }
      @sn_vlet_totals  = { }
      @sn_vlet_ttls    = { }
      @sn_vlet_secrets = { } # TODO: we don't support these yet
      super(key, key_prefix, kvc)
    end
    # :call-seq:
    #   each()
    #
    # Yields all respective values in the order they were loaded.
    def each
      @sn_vlets.keys.sort.each { |ser_num|
        @sn_vlets[ser_num].keys.sort.each { |value_num|
          v = ''
          @sn_vlets[ser_num][value_num].each { |vlet| v += vlet }
          kv = @key_value_class.new(@key, v)
          kv.serial = ser_num
          if @sn_vlet_ttls[ser_num] && @sn_vlet_ttls[ser_num][curr_val]
            kv.ttl = @sn_vlet_ttls[ser_num][curr_val]
          end
          yield kv
        }
      }
    end
    # :call-seq:
    #   each()
    #
    # Yields all serial values in no sorted order.
    def each_serial(*a, &c) @sn_vlets.keys.sort.each(*a, &c); end
    # :call-seq:
    #   get(serial_number)
    #
    # Returns an array containing all the
    # SerialKeyValue objects currently stored under the given serial
    # number; nil if non-existent.
    def get(ser_num)
      return nil if ! ser_num || ! @sn_vlets[ser_num]
      ret = [ ] # with SerialKeyValue, get returns an array of *KeyValue obj's
      @sn_vlets[ser_num].keys.sort.each { |value_num|
        v = ''
        next if ! @sn_vlet_totals[ser_num][value_num] # unknown badness ...
        0.upto(@sn_vlet_totals[ser_num][value_num]-1) { |vlet_num|
          if ! @sn_vlets[ser_num][value_num][vlet_num]: v = nil;  break; end
          v += @sn_vlets[ser_num][value_num][vlet_num]
        } # concatenate the value-lets
        next if ! v # some value-let badness existed; bail
        kv = @key_value_class.new(self.key, v) # make a new *KeyValue
        kv.key_prefix(self.key_prefix) # use our prefix
        kv.serial = ser_num # copy the serial number
        if @sn_vlet_ttls[ser_num][value_num] # copy the ttl
          kv.ttl = @sn_vlet_ttls[ser_num][value_num] 
        end
        ret.push(kv) # ... out the door
      }
      return nil if ret.length == 0
      ret
    end
    # :call-seq:
    #   get_latest
    #
    # Returns an array containing all the
    # SerialKeyValue objects currently stored under the latest (greatest)
    # serial number; nil if non-existent.
    def get_latest
      latest_num = @sn_vlet_totals.sort[-1]
      return nil if ! latest_num
      self.get(latest_num)
    end
    # :call-seq:
    #   length
    #
    # Returns the number of serial numbers currently stored.
    def length() @sn_vlets.length; end
    # :call-seq:
    #   size
    #
    # Returns the number of serial numbers currently stored.
    def size() @sn_vlets.length; end
    # :call-seq:
    #   latest_ttl
    #
    # Returns an array containing two elements:
    #   0. the latest TTL for the given serial number
    #   1. the array index of the element with the latest TTL
    def latest_ttl(ser_num, val=0)
      return nil if ! @sn_vlet_ttls[ser_num]
      latest = 0; latest_idx = -1;
      @sn_vlet_ttls[ser_num].each_key { |curr_val|
        if @sn_vlet_ttls[ser_num][curr_val] &&
          @sn_vlet_ttls[ser_num][curr_val] > latest
          latest = @sn_vlet_ttls[ser_num][curr_val] 
          latest_idx = curr_val
        end
      }
      [latest, latest_idx]
    end
    protected
    def unpack_vlet(vlet)
      return if ! vlet
      # all numbers that comes our way are TTLs
      if (vlet.is_a?(Fixnum) || vlet.is_a?(Bignum))
        if ! @sn_vlet_ttls[@last_sn]: @sn_vlet_ttls[@last_sn] = { }; end
        if (! @sn_vlet_ttls[@last_sn][@curr_val]) ||
         (vlet < @sn_vlet_ttls[@last_sn][@curr_val])
          return @sn_vlet_ttls[@last_sn][@curr_val] = vlet
        else return vlet; end
      end
      # anything else is a vlet
      ser_num, vlet_num, total_num, key, val = vlet.unpack('NCCZ*Z*')
      return nil if ! val || @key != key
      @last_sn = ser_num
      if    ser_num == 0 && vlet_num == 0: ser_num = next_unlabeled_serial_num
      elsif ser_num == 0: ser_num = @last_sn; end # we're in the middle of one
      if    ! @sn_vlets[ser_num]: @sn_vlets[ser_num] = {}; @curr_val = 0
      elsif vlet_num == 0: @curr_val += 1 end
      @sn_vlets[ser_num][@curr_val] = [] if ! @sn_vlets[ser_num][@curr_val]
      @sn_vlets[ser_num][@curr_val][vlet_num] = val
      @sn_vlet_totals[ser_num] = [] if ! @sn_vlet_totals[ser_num]
      @sn_vlet_totals[ser_num][@curr_val] = total_num
    end
    private
    def next_unlabeled_serial_num() @current_unlabeled_serial_num -= 1; end
  end
  
  # The basic object used to contain DHT-based key-value pairs.  It allows
  # setting of the "secret" used by OpenDHT to allow deletion, 
  # as the TTL (time to live).
  class KeyValue
    @@max_value_length = 1024 # OpenDHT default
    attr_accessor :key, :value, :ttl, :secret, :application, :key_values_class
    
    def initialize(key, value=nil, key_prefix='', ttl=18000, secret='secret',
      application='byu_p2pweb2', kvc=KeyValues)  # default ttl in seconds: 5 hours = 18000s
      @key_prefix       = key_prefix
      @key              = key_prefix + key
      @value            = value
      @secret           = secret
      @ttl              = ttl
      @application      = application
      @key_values_class = kvc
    end
    # :call-seq:
    #   key(key=nil)
    #
    # If provided, the key for this object set to that provided.  If not
    # provided, the current key (sans prefix) is returned.
    def key(key=nil) # allows transparent use of a key prefix
      if ! key
        @key[@key_prefix.length, @key.length-@key_prefix.length]
      else
        @key = @key_prefix + key
      end
    end
    # :call-seq:
    #   key_prefix(key_prefix=nil)
    #
    # If provided, the key prefix for this object set to that provided.
    # If no key prefix is provided, the current key prefix is returned.
    def key_prefix(key_prefix=nil)
      if ! key_prefix: @key_prefix
      else 
        @key_prefix = key_prefix
        @key        = @key_prefix + @key
      end
      @key_prefix
    end
    # :call-seq:
    #   storage_key
    #
    # Returns the key actually used for storage; likely only of value to
    # put(), get() and rm().
    def storage_key() @key; end
    # :call-seq:
    #   vlets() -> [ value-lets ]
    # 
    # Returns an array containing the value-lets contained in this object.
    def vlets()      [ @value ]; end
    def <=>(b)       @value <=> b.value; end
    # :call-seq:
    #   each()
    #
    # Yields the current value.
    def each()       yield @value; end
    # :call-seq:
    #   each_value()
    #
    # Yields the current value.
    def each_value() yield @value; end
  end
  
  # ExtendedKeyValue abstracts away the 1024 byte limitation on value
  # size imposed by OpenDHT by automatically splitting excessively long values
  # over multiple put()'s.  This adds two bytes of overhead
  # to the value: one byte to hold the current value and another to hold the
  # total number of values for the key.
  #
  # By default ExtendedKeyValue will automatically check that the given key
  # matches the key used to store the value.  In addition to the key, this
  # adds one byte of overhead to the value: a null to seperate the key and
  # value.
  class ExtendedKeyValue < KeyValue
    attr_reader :check_keys
    attr_writer :check_keys
    @@preamble_length = 3  # this is based on the "value-let" format below
    def initialize(*args)
      @check_keys  = true
      super(*args)
      self.key_values_class = ExtendedKeyValues
    end
    # :call-seq:
    #   vlet_length -> FixNum
    # 
    # Returns the length of a vlet (the payload).
    def vlet_length() (@@max_value_length-@@preamble_length-@key.length); end
    # :call-seq:
    #   vlets() -> [ value-lets ]
    # 
    # Returns an array of the value-lets already "contained" in this object. (that this object uses may be several)
    def vlets
      return [ ] if (! @value || @value == '')
      values      = [ ]
      curr_vlet   = 0
      curr_index  = 0
      if @value.class.to_s != 'String'
        print "WARNING can we do a non string [#{@value.class}!= String]into the DHT! ??"
        @value = @value.to_s
      end
      while curr_index <= @value.length
        values.push(self.pack_vlet(curr_index, curr_vlet))
        curr_vlet  = curr_vlet + 1
        curr_index = self.vlet_length * curr_vlet
      end
      values
    end
    # :call-seq:
    #   each()
    #
    # Yields all respective values in the order they were loaded.
    def each(*a, &c)       self.vlets.each(*a, &c); end
    # :call-seq:
    #   each()
    #
    # Yields all respective values in the order they were loaded.
    def each_value(*a, &c) self.vlets.each(*a, &c); end
    
    protected
    def pack_vlet(curr_index, curr_vlet)
      # Format: vlet_num vlet_tot serial_num key | value
      # here we use a total of 3 bytes plus key and value:
      #   | == \0 (1 byte)
      #   vlet_num   is an unsigned char (1 byte)
      #   vlet_tot   is an unsigned char (1 byte)
      #   key, value are strings (passed through)
      tot_vlet    = (  @value.length / self.vlet_length) +
       (((@value.length % self.vlet_length) == 0) ? 0 : 1)
      if @check_keys
        vlet = [curr_vlet, tot_vlet].pack('CC')       +
        @key                                 +
        [].pack('x')                         +
        @value[curr_index, self.vlet_length]
      else
        vlet = [curr_vlet, tot_vlet].pack('CC')       +
        @value[curr_index, self.vlet_length]
      end
      vlet
    end
  end # class
  
  # SerialKeyValue abstracts away the 1024 byte limitation on value
  # size imposed by OpenDHT by automatically splitting excessively long values
  # over multiple put()'s.  This adds two bytes of overhead
  # to the value: one byte to hold the current value and another to hold the
  # total number of values for the key.
  #
  # By default SerialKeyValue will automatically check that the given key
  # matches the key used to store the value.  In addition to the key, this
  # adds one byte of overhead to the value: a null to seperate the key and
  # value.
  #
  # Finally, SerialKeyValue allows the setting of a serial number for storage
  # of multiple values under the same number.  This adds four bytes (the serial
  # number is long) to the value in addition to the above.  It can be assigned
  # to using the serial method (and should be of numeric type). 
  class SerialKeyValue < ExtendedKeyValue
    attr_reader :serial
    attr_writer :serial
    @@preamble_length = 7  # this is based on the "value-let" format below
    def initialize(*args)
      @serial = 0
      super(*args)
      self.key_values_class = SerialKeyValues
    end
    protected
    def pack_vlet(curr_index, curr_vlet)
      # Format: vlet_num vlet_tot serial_num key | value
      # here we use a total of 7 bytes plus key and value:
      #   | == \0 (1 byte)
      #   vlet_num   is an unsigned char (1 byte)
      #   vlet_tot   is an unsigned char (1 byte)
      #   serial_num is a long (4 bytes)
      #   key, value are strings (passed through)
      tot_vlet = (  @value.length / self.vlet_length) +
       (((@value.length % self.vlet_length) == 0) ? 0 : 1)
      [@serial, curr_vlet, tot_vlet].pack('NCC') +
      @key                                     +
      [].pack('x')                             +
      @value[curr_index, self.vlet_length]
    end
  end
  # ltodo sometime lookup how much of the time is spent waiting for DNS oasis (eck)
  #
  # The OpenDHT interface class. 
  #
  #
  class GotEnoughRandomGateways < StandardError
  end
  class Hash
    attr_reader :default_key_value_class, :num_retries
    attr_writer :default_key_value_class, :num_retries
    @@max_value = 2**31-1
    @@useMultiHomed = true # ltodo a new variable 'use proximal gateways'
    # :call-seq:
    #   new(gateway)
    #
    # Creates a new OpenDHT::Hash object using the optional given
    # gateway as address.  If not provided, http://opendht.nyuld.net:5851
    # is used.
    #
    # By default the underlying *KeyValue object is ExtendedKeyValue; this
    # can be changed by setting Hash#key_value_class to the desired type.
    # vltodo with options within classes have 'test self' run multiple times
    @@receiveAnswerTimeOut = 45
    def initialize(gw = nil, logger = nil)
      gw ||= DEFAULT_GATEWAY
      @savedPms = {} # share the wealth among threads
      @serverListEntryVariable = ConditionVariable.new
      @serverListMutex = Mutex.new
      logger ||= Logger.new("../logs/opendht_rubyforget_generic_output.txt", 1000, "opendht_rubyforge")
      @logger = logger # ltodo take out
      @num_retries = DEFAULT_NUM_RETRIES
      @default_key_value_class = ExtendedKeyValue # ltodo is this too 'intense' for us? :) I think it may be ok for our single entries, though :)
      @servers = [gw] # temporarily for early finders - shouldn't matter, once we verify the new ones...this could use some help, though works
      init_gateway = @servers
      @nextGatewayNumberToUse = 0
      debug "using (possibly temporarily) dht gateways:" + @servers.inspect # ltodo servers rechecked once per instance, really...
     if @@useMultiHomed
      Thread.new { 
        begin
          countNumberOfNonRandom = 0
          calculateGoodSecondGatewayBlockingAndWriteToFile(10, false, true, false){ |newGatewayToAdd, style|
            pp "got \n\n\n\n\n", newGatewayToAdd, style
            @serverListMutex.synchronize {
                #debug "got new #{style} gateway #{newGatewayToAdd}!"
                if @servers == init_gateway
                   #debug "and over riding the default gateway with it"
                   @servers = [] # ltodo at this point you want to 'release' any waiting, see if they can get in...
                end
                
                if style == :fast
                    debug "and overriding random #{@servers[countNumberOfNonRandom]} with it"
                    @servers[countNumberOfNonRandom] = newGatewayToAdd
                    countNumberOfNonRandom += 1
                else
                    @servers << newGatewayToAdd  # got a rand
                end
            }
          }
        rescue Exception => detail
          error "arr #{detail}"
        end
      }.join


     end
    end
    CACHED_PROXY_NAME = 'known_good_opendht_proxies' # unused
    
    def peerToGateway(peer, port)
      return "http://#{peer}:#{port}"
    end
    CACHED_ALL_GATEWAYS_FILE_NAME = "cached_all_gateways_file_name" 
    def calculateGoodSecondGatewayBlockingAndWriteToFile number, wantRandom, wantSemiRandom, wantNonRandom # wantNonRandom is still semi random...sigh.
      EventMachine.fireSelfUp
      assert block_given?
      assert((wantRandom or wantSemiRandom or wantNonRandom), "need at least one type of gateway!")
      assert((wantRandom ^ wantSemiRandom ^ wantNonRandom), "cant have more than one type! #{[wantRandom, wantSemiRandom, wantNonRandom].join(' ')}") # ltodo this isn't all inclusive.
      allServers = nil # ltodo rename text
      if File.exists?(CACHED_ALL_GATEWAYS_FILE_NAME) and File.fileSize(CACHED_ALL_GATEWAYS_FILE_NAME) > 0
          debug "using cached proxies instead of downloading list"
          File.open(CACHED_ALL_GATEWAYS_FILE_NAME) { |f|
            allServers = f.read
          }
      else
        require 'open-uri'
        begin # ltodo note that if you save it to a file, currently say you do this, then start it the next day, it might have some 'now dead' servers saved (?)
          url = open('http://opendht.org/servers.txt') # ltodo cache this file!
          timeLine = url.readline
          allServers = url.read
          if !allServers
            print "\n uh oh unable to download servers...ahh well\n"
            return # no dice
          end
          url.close
          File.open(CACHED_ALL_GATEWAYS_FILE_NAME, "wb") { |f|
            f.write allServers
         }
        rescue StandardError, Timeout::Error => detail
          print "ERROR SEEDO unable to download servers file to get new gateways" + detail.to_s + detail.class.to_s
          return nil # no dice there
        end
      end
      allServers = allServers.split("\n")
      allServerArrays = []
      for server in allServers
        allServerArrays << [server.split("\t")[1].split(':')[0], 5851]
      end
      allServerArrays = allServerArrays.randomizedVersion
      begin # could have contention for this file
        if wantRandom or wantSemiRandom
            if wantRandom
                numberRandomDesired = number
            elsif wantSemiRandom
                numberRandomDesired = number/2
            else
                assert false , "we never get here"
            end

            totalGot = 0
            gotMutex = Mutex.new
            threadRaceInjectsGiveUp(Array.new(numberRandomDesired), nil, true, GotEnoughRandomGateways, false, false, true) { |unused| 
            begin
              
            loop do
             nextPeer = allServerArrays.shift
             if EventMachine.portOpen? nextPeer[0], nextPeer[1]
                #debug "got good random #{nextPeer.inspect}"
                yield peerToGateway(nextPeer[0], nextPeer[1]), :random
              gotMutex.synchronize {
                totalGot += 1
                if totalGot == numberRandomDesired
                    raise GotEnoughRandomGateways, "yep #{totalGot} versus desired was #{numberRandomDesired}"
                else
                    # don't break, let it kill us
                end
              }
             else
                  debug "bad gatway listed in your cached opendht gateways list! #{nextPeer.inspect}"
                  if allServerArrays.empty? 
                      error "ack ran out of opendht gateways to try"
                      break
                  end
             end
            end

             rescue GiveUp

             end
            }
        end

        if wantSemiRandom or wantNonRandom
               if wantNonRandom
                   numberFast = number
               elsif wantSemiRandom
                   numberFast = (number.to_f/2).ceil
               else
                   assert false
               end
               assert number <= 10
               goodPeers = calculateXQuickestPorts allServerArrays, numberFast, 10 
               pp 'good peers are', goodPeers, "\n\n\n\n"
               numberFast.times do 
                   nextPeer = goodPeers.shift
                   debug "got good fast #{nextPeer.inspect}"
                   yield peerToGateway(nextPeer[0], nextPeer[1]), :fast # ltodo this is a little slow, but not too bad, as it first waits for them all to come in, then adds them
               end
        end
        # the old way is to write them to a file, though we don't use that anymore ltodo rename
        #fileOut = File.new(CACHED_PROXY_NAME, 'wb')
        #fileOut.write gateways.join("\n")
        #fileOut.close
      rescue => detail
        print "\n uh oh contention for getting gateways or writing the gateway file, or other failure #{detail} #{detail.class} #{detail.backtrace.join(' ')}"
      end
    end


        def doServerCall printableString, gateways, &blocky
          assert block_given?
            
            debug "doing doServerCall #{printableString} with gw's #{gateways.inspect}"
            assert gateways.class == Array
            assert gateways.length >= 1
          startTime = Time.new
        valueBack = threadRaceInjectsGiveUp(gateways, nil, true, NeverThrown, false, true) { |gatewayInternal| 
         result1=result2 = nil
         begin
              server = XMLRPC::Client.new2(gatewayInternal, nil, @@receiveAnswerTimeOut) # this does indeed create a new server in memory each time.  If a bottleneck use a pool (?)
              result1 = result2 = nil
              Timeout::timeout(@@receiveAnswerTimeOut) {
                result1, result2 = blocky.call(server) # have its block return me the return values...ltodo check if this '1' and '2' and '0' are right!
              }
              if result1 == 1 
                raise OverCapacityError
              end
              if result1 == 2
                raise TryAgainError
              end
              # getting here might still include exceptions
        rescue StandardError, Timeout::Error => detail 
        # silly rexml grabs one of my exceptions! it should just turf those!  # , REXML::ParseException
          # IOError may be generated in error, when Ruby closes a wrong stream (ugh) of course, typeError seems odd, too 
          reportString = "failed or abandoned (too slow) a single opendht #{printableString} time after #{(Time.new - startTime).to_f}s-- gw:#{gatewayInternal} possibly retrying [#{printableString}] ...detail[#{detail} #{detail.class}]" 
          
          if detail.class != Timeout::Error and detail.class != Errno::ECONNRESET and detail.class != Errno::ECONNREFUSED and detail.class != OpenDHT::OverCapacityError and detail.class != SocketError and detail.class !=  EOFError and detail.class != Errno::EHOSTUNREACH and detail.class != GiveUp
            if detail.class == ThreadError
                reportString += "I think this is a critical that...ummm...either gets transferred [very weirdly -- ruby mistake] or interrupted [my mistake]" end
            if detail.class == IOError
                reportString += "A ruby error of closing my port early, I believe"
            end
            reportString += 'bt: ' + detail.backtrace.join('..')
            error reportString
          else
            debug reportString
          end
          if detail.class == GiveUp or detail.class == P2PTransferInterrupt # this is so annoying!
              debug "raising #{detail.class} #{reportString}"
              raise
          else
            debug "OpenDHT internals FAILED MISERABLY [giving up, returning nil, though perhaps for a single redundant] after #{(Time.new - startTime).to_f}s " + printableString.to_s # ltodo for gets, don't loop here, loop outside :)
            # ltodo raise always raise OpenDHTFailure.new("ERROR OpenDHT FAILED MISERABLY [giving up]" + argsAsArray.to_s)
          end
        end # rescue
        [result1, result2]
      } # thread race to return non nil
      if !valueBack
          debug "ack returning a kind of a failure for this round of doServerCall #{printableString} with gw's #{gateways}"
      end
      debug "got results #{valueBack.inspect} #{printableString} with gw's #{gateways}"
      return valueBack
     end

    def repeatServerCallTillSuccessful(numberOfTimesToRepeat, printableString, gateway=DEFAULT_GATEWAY, useUniqueDifferentGatewaysEachTime = nil, &block)
      assert !gateway if useUniqueDifferentGatewaysEachTime
      if gateway.class == Array
          assert !useUniqueDifferentGatewaysEachTime, "sanity for how we use this to either be one then another, or all at once"
      end
      if !gateway.nil? and gateway.class != Array
          gateway = [gateway]
      end
      assert block_given?
      startTime = Time.new.to_f
      timesTried = 0
      # I think it needs a new server every time, even the first, in case it gets passed in the same server [ugh] ltodo fix better
      loop do
          gateway = [getNextGatewayInList] if useUniqueDifferentGatewaysEachTime
          localStartTime = Time.new
          answer = doServerCall printableString, gateway, &block
          debug "got answer #{answer.inspect} to #{printableString} which, if not nill, I am returning (after #{Time.new - localStartTime}s)"
          if answer
              debug "returning"
              return answer
          else
              debug "not returning"
          end
            
          if timesTried < numberOfTimesToRepeat
            debug "retrying #{printableString} after (total time) #{Time.new - startTime}, for the #{timesTried} time"
            timesTried += 1; 
            retry 
          end
          break
      end # loop do
      debug "ack failed #{[numberOfTimesToRepeat, printableString, gateway, useUniqueDifferentGatewaysEachTime].join(' ')}"
      return false
    end # func
    
    # ltodo cdf's always [0,0],[1,1]
    def getNextGatewayInList
    @serverListMutex.synchronize {
      @nextGatewayNumberToUse += 1
      ourUniqueGateway =  @servers[@nextGatewayNumberToUse % @servers.length]
      assert ourUniqueGateway
      return ourUniqueGateway
    }
    end
    

    def error m
     @logger.error "opendht_rubyforge:" + m.to_s
    end

    def debug m
     @logger.debug "opendht_rubyforge:" + m.to_s
    end

    def doPutCall(keyval, vlet)
      keyOut = keyval.key.to_sha.to_xmlrpc_base64
      valueOut = vlet.to_xmlrpc_base64
      secretOut = keyval.secret.to_sha.to_xmlrpc_base64 # when calling put you give the hash
      debug "for put #{keyval.key} using unique gateways once" # ltodo ideally inside this other next loop youwould rotate servers...ahh well 
      returnVal = repeatServerCallTillSuccessful(@num_retries, "put #{keyval.key} => #{vlet}", nil, true) { |server| 
                server.call('put_removable', keyOut, valueOut, 'SHA', secretOut, keyval.ttl, keyval.application )
      }
      returnVal
    end
    
    # :call-seq:
    #   put(KeyValue kv) -> true | false
    #
    # Performs a put using the given key and value on the DHT instance we
    # are using.
    # 
    def put(keyval) # this is used internally to 'set' a KeyValue in the DHT...assuming it knows how to create 'vlets' which are what it sets.
      res = 0
      keyval.vlets.each { |vlet|
        res = doPutCall(keyval, vlet)
      }
      true # ltodo is this used?
    end
    
    def getAsArrayOfValues(thisKey, returnTen = true)
      answerObj = get(thisKey, @@max_value, returnTen)
      assert answerObj
      return answerObj.allAsArray
    end
   # tlodo break this up into two files--the very base stuff, and then things that sit on that. 
    def get(keyval, max=@@max_value, returnTen = true) # only used internally, I think! tlodo investigate
      return getKeyValuesObjectsOrEmptyArray(keyval, max, returnTen)
    end
    
    # :call-seq:
    #   get(KeyValue kv, Fixnum maximum) -> *KeyValues
    # 
    # Performs a get using the given key on the DHT instance we
    # are using.  Optionally, allows setting of the 
    # maximum number of bytes we
    # are to return; currently uses the class default (2^31-1).
    # 
    
    
    def doGetCall(keyval, max, pm, timesToRepeat = @num_retries, gateways=DEFAULT_GATEWAY)
      keyvalOut = keyval.key.to_sha.to_xmlrpc_base64
      
      # ltodo here's where it should split, thread-wise.
      debug "doing get call #{@num_retries} times"
      returnValin, pmIn = repeatServerCallTillSuccessful(timesToRepeat, "get #{keyval.key}", gateways)  { | server| 
        server.call('get_details', keyvalOut, max, Hash.binary(pm), keyval.application) 
      }
      
      if not returnValin # disallow pm from getting nuked, which hurt bad once
        return nil, ''
        returnVal = nil # disallows pm from getting nuked, which is a bad, bad thing for slow hosts, causes some repeating loop or other.  Bad. ltodo look inot this
        pm = '' # backup
      else
        returnVal = returnValin
        pm = pmIn
      end
      
      return returnVal, pm
      
    end
    
    class JustFinishedException < StandardError
    end
    
    class QuitWorkingException < StandardError
    end
    
    def runThreadsThatWillThrowWhenTheyWinOfBlock argArray
      assert block_given?
      allThreads = []
      for parameter in argArray
        allThreads << Thread.new(parameter) {|parameter|
          yield parameter # pass it its parameter
        }
      end
      
    end
   
    # this basically gets values, chucks them into a keyvals object structure, for it to parse them
    def getKeyValuesObjectsOrEmptyArray(keyval, max=@@max_value, onlyReturnTen = true) # just for reading them in, kind of raw (I think) then they process via <<
      #debug "getting #{keyval} external blind to gateways"
        # ltodo what if one returns [] .allAsArray and other does not?  hmm hmm when I notice it... :) [put it in to notice it {not kill threads, print it out 'I lost!' but got these items!'
      myAnswer = getKeyValuesObjectsOrEmptyArrayInternal(keyval, max, onlyReturnTen)
      assert myAnswer.class != Array # it's a weird internal structure muhaha
      return myAnswer
    end
    class SuccessThrow < StandardError
    end
    #@@numberOfGateways = 1 # for if you want to fork individual requests to gateways...
    def getKeyValuesObjectsOrEmptyArrayInternal(keyval, max, returnLatestKnownTenAndUseStoredPm) # always move PM forward, or to its last, unless !useStoredPMNotStartFromBeginning
      keyval = @default_key_value_class.new(keyval) if keyval.is_a?(String)
      keyvals = keyval.key_values_class.new(keyval.key)
      # ltodo look into how the threads play into this...like an old thread might nuke the latest one, etc.
      # vltodo use a 'for each' style, with a yield.  Oh yeah :)
       
      # place mark -- if returned it means that openDHT didn't return all of the data and another get will (with that pm passed in)

      if returnLatestKnownTenAndUseStoredPm and @savedPms.has_key?(keyval.key)
        pm = @savedPms[keyval.key]
        #debug "using cached pm for #{keyval.key} #{pm.inspect}"
      else
        #debug "using fresh pm for #{keyval.key}"
        pm = '' # start from the beginning
      end

	loop do # for all pm's loop
        	# pm if not '',  means more
        pmUsed = pm  
        startTime = Time.new
        #debug "doing get #{keyval.key} with pm #{pm.inspect}"
        values=nil
        alreadyGotAnAnswer = false
        gotAnswerMutex = Mutex.new
        #tlodo we need to only throw success once
        shouldThrowAsSuccessfullWinEvenIfGotNothing = true
        stillHere = Mutex.new
        assert stillHere
        assert stillHere.class == Mutex

        values, pm = doGetCall(keyval, max, pm, @num_retries, @servers)

       debug "post thread race for #{keyval.key}"
       if !values
           debug "apparently both gateways did not work #{keyval.key}"
           values = [] # ltodo is this not necessary? huh?
# pm is set as either '' or pmused, at the top of the loop
        end
        values.each { |vlet|    # TODO: secrets
          begin
            if keyvals << vlet[0] # value / vlet -- these are defined by the interior class -- let them process them
              keyvals << vlet[1]  # TTL
            end
          rescue IndexError => detail
            raise TryAgainError.new("IndexError == possible that some other program (someone else?) used that key, not this program!")
          end
        } if values
        assert pm
        
        if pm != '' # save it if we are here to get just 10, or if we are progressively moving forward and got a match
          assert pm.length > 0 
          #debug "got pm not equal (!=) blank [after processing #{values.length} (total this round of rounds of #{keyvals.length}) for query -> #{keyval.key}] pm = #{pm.inspect}!"
          if (@savedPms.has_key? keyval.key and @savedPms[keyval.key] == pmUsed) or (!@savedPms.has_key? keyval.key) # save the 'next one' for next time...I don't anticipate thread probs, as the first back saves it, instructs other thread to die, so...minimal [but ltodo ensure none ever] ltodo ensure threads only progress forward
             # debug "saving pm for #{keyval.key} after #{Time.new - startTime} #{pm.inspect}"
              @savedPms[keyval.key] = pm 
          else
              if @savedPms[keyval.key] == pm
                  #debug "I would have saved the same thing that's there now for teh pm for #{keyval.key}!"
              else
                #debug "hmm double key sync error for this round  for #{keyval.key} not saving pm for #{keyval.key} after #{Time.new - startTime}, as it had changed somehow -- I had anticipated #{pmUsed.inspect}, was now set to #{@savedPms[keyval.key].inspect}, I would have wanted to set it to #{pm.inspect} -- ahh well -- with the next loop I should use the 'better' key"
              end
          end
          break if returnLatestKnownTenAndUseStoredPm # ltodo we need a single global giver of peers, to avoid any redundancy.  We just do.
          #debug "keeping going, from beginning on till end, for key  #{keyval.key}"
        else
          #debug "got pm == blank! End!" # we dont have to worry about saving, because I believe it will have been done above [though this is gross and could cause some problems ltodo analyze
          if !returnLatestKnownTenAndUseStoredPm # then we should save the last one arbitrarily...I think.
              if pmUsed != '' # ltodo have it ummm...not do triple or 5x redundancy on the same query!
                  if @savedPms[keyval.key] != pmUsed
                      #debug "hmm I got to the end of a list and then there was a sync error with the saved pm -- you'd think it would have been stored above, with each loop, but must have gotten confused--saving anyway"
                      @savedPms[keyval.key] = pmUsed
                  else
                      #debug "success in the DHT loops above"
                  end
              else
                # used '' and got '' -- no worries just got an intro 10 loop
              end
          else
                # we wanted 10 at a time, total, got less than that, so the 'saved' or 'none' pm should be good for the next round
          end
# could delete the key to 'start over' from the beginning, but that's not good
            #debug "NOT deleting pm for #{keyval.key} -- I hope this will help us just continue onward" #          @savedPms.delete(keyval.key) if @savedPms.has_key? keyval.key # restart the next time [ltodo detect if it's an error, don't restart]
          break # unconditionally out of the loop--no more pm loopingi this time!
        end

          # let the loop continue
          debug "looping for another 9 -- for sure legitimately this time"
        end # loop do
      keyvals
    end
    
    # ltodo double check if we use a max get -if now then do it- like max 40 peers or something! and test it
    def removeKeyValuePair(key, value)
      keyval = @default_key_value_class.new(key, value)
      rm(keyval)
    end

    # :call-seq:
    #   rm(KeyValue kv) -> true | false
    # 
    # Performs a remove using the given key on the DHT instance we
    # are using.  Notably, one should make sure that the time-to-live and the
    # secret set in the KeyValue object are appropriate for deleting the given
    # object.
    #
    
    def doRemoveCall(server, keyvalObject, vlet)
      return repeatServerCallTillSuccessful(@num_retries, "rm #{keyvalObject.key}", nil, true){ | server| 
        server.call('rm',
        keyvalObject.key.to_sha.to_xmlrpc_base64,
        vlet.to_sha.to_xmlrpc_base64,
                            'SHA',
        keyvalObject.secret.to_xmlrpc_base64,
        keyvalObject.ttl, # needed for rm -- interesting...maybe if there are two of the same? except its value seems to not matter...for rm...I don't think....might...
        keyvalObject.application)
      }# I think this one works
    end
    
    def rm(keyval)
      # ltodo check if this works then there is discrepancy between .vlets if created via constructor or through DHT.  that is bad.
      if keyval.is_a?(String)
        keyvalObject = @default_key_value_class.new(keyval)
      else
        keyvalObject = keyval
      end
      
      keyvalObject.vlets.each_with_index { |vlet, index| # arrays with single values...odd...[part of other todo]

      # turns out that doing 'two at once' just overloads openDHT, not anything else that might have been positive
        res = doRemoveCall(@server, keyvalObject, vlet)
      }
      true
    end
    # :call-seq:
    #   [](key)
    #
    # Attempts to retrieve the hash entry with the given key.  Stores the key
    # and value in, and with the semantics of, the type given by instance
    # variable
    # @default_key_value_class; defaults to ExtendedKeyValue.
    #
    # Note that all *KeyValue types are capable of returning more than one
    # value on a get().  However, the array index method returns only the
    # latest value by the given *KeyValue type (generally as defined by the
    # TTL returned).  If you want access
    # to others, you'll need to use the slightly less pretty get() method
    # directly.
    def [](key)
      kv = self.get(@default_key_value_class.new(key)).get_latest
      return kv.value if kv
      return nil
    end
    # :call-seq:
    #   []=(key, value) -> value
    #
    # Attempts to store the hash entry with the given key and value.  Stores
    # the key
    # in and with the semantics of the type given by instance variable
    # @default_key_value_class.
    def []=(key, val)
      self.put(@default_key_value_class.new(key, val))
      val # chain
    end

    alias :setNewKeyValuePair :[]=
    protected
    def Hash.binary(value) assert value; XMLRPC::Base64.new(value, :dec); end
    def Binary(value) return Hash.binary(value) end # ltodo not use :)
    
    # set up gateways, if desired...
    
    def Hash.testSelf
         Hash.testSelfInternal
         @@fastestGateway = 'http://bunk' #tlodo do this
         Hash.testSelfInternal

         testArray = [1,2,3]
         slice, newTest = testArray.sliceOffFrontAndPutAtBackReturnsTwo!(1)
         assertEqual slice, [1]
         assertEqual newTest, [2,3,1]
         testArray = [1,2,3]
         slice, newTest = testArray.sliceOffFrontAndPutAtBackReturnsTwo!(2)
         assertEqual slice, [1,2]
         assertEqual newTest, [3,1,2]
         print "passed hash"

    end
# ltodo put the basic guts in a separate file--gross!
    def Hash.testSelfInternal

      gateToUse = "http://opendht.nyuld.net:5851"
      
      subject = OpenDHT::Hash.new  gateToUse
      subject.calculateGoodSecondGatewayBlockingAndWriteToFile(5, true, false, false) {|incoming, style| print "got #{incoming} #{style}!"}
      hash = OpenDHT::Hash.new gateToUse
      print "hash test/opendht test"
      
      key = rand(1000).to_s
      value = 'value_i_put'
      a = KeyValue.new(key, value, 'secret')
      vlet = a.vlets()[0]
      server  = XMLRPC::Client.new2(gateToUse)
      
      hash.doPutCall(a, vlet) # ltodo a and vlet are redundant?
      sleep 3
      values, pm = hash.doGetCall(a, 1000, '')
      assertEqual values[0][0], value
      assert values.length == 1
      
      # add another
      b = KeyValue.new(key, 'value_i_put_again', 'secret')
      vlet2 = b.vlets()[0]
      hash.doPutCall(b, vlet2)
      values, pm = hash.doGetCall(a, 1000, '') #doGetCall(keyval, max, pm)
      assert values.length == 2
      
      
      # now remove it
      hash.doRemoveCall(server, a, vlet)
      values, pm = hash.doGetCall(a, 10, '') #doGetCall(keyval, max, pm)
      assert values.length == 1
      assertEqual values[0][0], 'value_i_put_again'
      print "PASSED test 1!"
      
      ############      
      print "hash test/opendht second test"
      subject = OpenDHT::Hash.new  gateToUse
      key = rand(1000).to_s + "_our_test_key"
      subject[key] = '3' # put
      current = subject.get(key)
      assert current.length == 1 # get
      p "should be 3:" # ltodo just look into it, assert that
      assertEqual current.allAsArray[0], "3"
      
      print "about to delete!\n"
      subject.removeKeyValuePair(key, '3') #rm
      
      print "getting again after deletion..."
      subject = OpenDHT::Hash.new
      current = subject.get(key) # get
      assert current.length == 0
      
      
      #####test 3: save like 25, make sure we can read back all 25...
      [[false, 1], [true, 2]].each { |arg, timesToRunIt|  # has the number of times to try to get
      allWrote = {}
      key = '25x_key' + rand(1000000).to_s
      
      21.times {|n|       
        writeThisTime = '25x_value' + n.to_s
        hash[key] =  writeThisTime
        print '.'
        STDOUT.flush
        allWrote[writeThisTime] = 1
      } # ltodo better put function...ugh...
      receivedCount = 0
      timesToRunIt.times {
        received = hash.getAsArrayOfValues(key, arg)
        for receivedItem in received do
          assert allWrote.has_key?(receivedItem)
          allWrote.delete(receivedItem)
        end
        receivedCount += received.length
        }
      assertEqual receivedCount, 21
      assertEqual allWrote.length, 0
      lengthOfRead = hash.getAsArrayOfValues(key, true).length
      assert lengthOfRead > 0
      }

      print "passed ALL!!!!!"
    end
# this is run just once
    
  end # class Hash
  
end # module OpenDHT
# ltodo have it try all, get closest, a few threads at a time (why rush, now?)
       # ltodo tell Ruby "for receivedItem in received {}" should work! Why not?

if $0 == __FILE__
   print "don't know what to do!"
end
