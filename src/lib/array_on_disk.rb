require 'tempfile'

class ObjectOnDisk
    def initialize object_to_start_with
      @file = Tempfile.new 'diska' + rand(1000000).to_s
      @file.write Marshal.dump(object_to_start_with)
      @file.close # the norm is for the temp file to be closed
      @current_self = nil
    end

    def dup
      read
      @current_self
    end
    
    def method_missing meth, *args
      read
      if block_given?
        out = @current_self.send(meth, *args) { |*args2| yield(*args2)}
      else
        out = @current_self.send(meth, *args)
      end
      write
      out
    end
    
    def plus_equals add_this
      read
      @current_self += add_this
      write
    end
    
    private

    def read
      @file.open
      @current_self = Marshal.load @file.read
      @file.close
    end

    def write
      raise unless @current_self
      @file.open
      @file.write Marshal.dump(@current_self)
      @file.close
      @current_self=nil
    end

    def close
      @current_self = nil
    end

end 

class ArrayOnDisk < ObjectOnDisk

  def initialize
    super []
  end
  
end

   
# let's see...
# doctest: diskarray loads values
# >> a = ArrayOnDisk.new
# >> a << 3
# >> a << 4
# >> a.dup
# => [3, 4]
# >> b = []
# >> a.each_with_index {|guy, index| b << [guy, index]}
# >> b
# => [[3, 0], [4, 1]]
# >> b = ArrayOnDisk.new
# >> b << [1, 1]
# >> b[0]
# => [1, 1]
#
# doctest: works with integers
# >> a = ObjectOnDisk.new 3
# >> a.dup
# => 3
# >> b = fork; if !b; a.plus_equals 3; exit!; end; 
# >> Process.waitpid(b)
# >> a.dup
# => 6
