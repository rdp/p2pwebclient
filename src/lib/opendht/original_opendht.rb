# opendht.rb -- a Ruby OpenDHT access implementation
#
# (C) 2006, John Russell Lane, SORA Project, The University of Tokyo
#
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

class String
  def to_sha
    d = Digest::SHA1.new
    d << self
    d.digest
  end
  def to_xmlrpc_base64()   XMLRPC::Base64.new(self, :dec); end
  def from_xmlrpc_base64() XMLRPC::Base64.new(self, :enc); end
  def to_hex() self.unpack('H*')[0]; end
end

module OpenDHT

  DEFAULT_NUM_RETRIES = 3
  DEFAULT_GATEWAY = 'http://opendht.nyuld.net:5851'

  class OverCapacityError < RuntimeError; end
  class TryAgainError     < RuntimeError; end

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
      @vlets        = [ ]
      @vlet_totals  = [ ]
      @vlet_ttls    = [ ]
      @vlet_secrets = [ ] # TODO: as yet, unused
      super(key, key_prefix, kvc)
    end
    # :call-seq:
    #   each()
    #
    # Yields all respective values in the order they were loaded.
    # todor hangs on request an empty key-value pair
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
    end
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
    def get_latest() self.get(self.latest_ttl[1]); end
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
    attr_reader :key, :value, :ttl, :secret, :application, :key_values_class
    attr_writer :key, :value, :ttl, :secret, :application, :key_values_class
    def initialize(key=nil, value=nil, key_prefix='', ttl=120, secret='secret', 
                   application='Ruby::OpenDHT', kvc=KeyValues)
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
    # Returns an array of the value-lets contained in this object.
    def vlets
      return [ ] if (! @value || @value == '')
      values      = [ ]
      curr_vlet   = 0
      curr_index  = 0
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
  end

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

  #
  # The OpenDHT interface class.
  #
  class Hash
    attr_reader :default_key_value_class, :num_retries
    attr_writer :default_key_value_class, :num_retries
    @@max_value = 2**31-1
    # :call-seq:
    #   new(gateway)
    #
    # Creates a new OpenDHT::Hash object using the optional given
    # gateway as address.  If not provided, http://opendht.nyuld.net:5851
    # is used.
    #
    # By default the underlying *KeyValue object is ExtendedKeyValue; this
    # can be changed by setting Hash#key_value_class to the desired type.
    def initialize(gw='http://opendht.nyuld.net:5851')
      @num_retries = DEFAULT_NUM_RETRIES
      @default_key_value_class = ExtendedKeyValue
      if gw: self.gateway(gw)
      else   self.gateway(DEFAULT_GATEWAY) end
    end
    #
    # :call-seq:
    #   gateway(url)
    #
    # Sets the gateway address used by the object to that given.
    #
    def gateway(value=DEFAULT_GATEWAY)
      return @gateway if (! value)
      @gateway = value unless (! value)
      @server  = XMLRPC::Client.new2(@gateway)
      @gateway
    end
    # :call-seq:
    #   put(KeyValue kv) -> true | false
    #
    # Performs a put using the given key and value on the DHT instance we
    # are using.
    def put(keyval)
      retries = res = 0
      keyval.vlets.each { |vlet|
        begin
          res = @server.call('put_removable',
                             keyval.key.to_sha.to_xmlrpc_base64,
                             vlet.to_xmlrpc_base64,
                             'SHA',
                             keyval.secret.to_sha.to_xmlrpc_base64,
                             keyval.ttl,
                             keyval.application)
          raise OverCapacityError if res == 1
          raise TryAgainError     if res == 2
        rescue Timeout::Error, Errno::ECONNREFUSED
          if retries < @num_retries: retries += 1; retry; end
          raise
        end
      }
      true
    end
    # :call-seq:
    #   get(KeyValue kv, Fixnum maximum) -> *KeyValues
    # 
    # Performs a get using the given key on the DHT instance we
    # are using.  Optionally, allows setting of the 
    # maximum number of bytes we
    # are to return; currently uses the class default (2^31-1).
    def get(keyval, max=@@max_value)
      retries = 0
      keyval = @default_key_value_class.new(keyval) if keyval.is_a?(String)
      keyvals = keyval.key_values_class.new(keyval.key)
      pm = ''
      loop do
        begin
          values, pm = @server.call('get_details',
                                    keyval.key.to_sha.to_xmlrpc_base64,
                                    max,
                                    binary(pm),
                                    keyval.application)
        rescue Timeout::Error, Errno::ECONNREFUSED
          if retries < @num_retries: retries += 1; retry; end
          raise
        end
        values.each { |vlet|    # TODO: secrets
          if keyvals << vlet[0] # value / vlet
            keyvals << vlet[1]  # TTL
          end
        }
        break if pm == ''
      end
      keyvals
    end
    # :call-seq:
    #   rm(KeyValue kv) -> true | false
    # 
    # Performs a remove using the given key on the DHT instance we
    # are using.  Notably, one should make sure that the time-to-live and the
    # secret set in the KeyValue object are appropriate for deleting the given
    # object.
    #
    def rm(keyval)
      retries = 0
      keyval.vlets.each { |vlet|
        begin
          res = @server.call('rm',
                            keyval.key.to_sha.to_xmlrpc_base64,
                            vlet.to_xmlrpc_base64,
                            'SHA',
                            keyval.secret.to_sha.to_xmlrpc_base64,
                            keyval.ttl,
                            keyval.application)
          raise OverCapacityError if res == 1 # ???
          raise TryAgainError     if res == 2
        rescue Timeout::Error, Errno::ECONNREFUSED
          if retries < @num_retries: retries += 1; retry; end
          raise
        end
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
    protected
    def binary(value) XMLRPC::Base64.new(value, :dec); end
  end # class Hash

end # module OpenDHT

