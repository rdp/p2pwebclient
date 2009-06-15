
class File
  if RUBY_PLATFORM =~ /mingw|mswin/
    File.open('temp_file', 'w') {}
    @@saver_file = File.new  'temp_file', 'r'
  else
    @@saver_file = File.new '/dev/random', 'r' # save a descriptor for our own purposes muhaha
  end
  def self.append_to to_this_file, data
    begin
      to_this = File.new to_this_file, 'a+'
      size = to_this.write data
      to_this.close
      raise 'bad'unless size == data.length
      return size
    rescue => e
      print "EMERGENCY WRITE to #{to_this_file}\n"
      begin
        @@saver_file.close
        to_this = File.new to_this_file, 'a+'
        length = to_this.write data
        to_this.close
        raise 'bad' unless length == data.length
        return length
      rescue => e
        print "FATAL FAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAIL"*10
        raise
      ensure
        @@saver_file = File.new '/dev/random', 'r'
      end
    end
    
  end
  
  def self.read_from this_file, length = nil, offset = nil
    begin
      out = File.read this_file, length, offset
      raise 'bad' unless out.length == length if length
      out
    rescue => e
      print "EMERGENCY READ\n"
      begin
        @@saver_file.close
        length = File.read this_file, length, offset
        raise 'bad' unless length == length if length
        return length
      rescue => e
        print "222222FAIIIIILLLLLL #{e}"*10
        raise
      ensure
        @@saver_file = File.new '/dev/random', 'r'
      end 
    end
  end
  
end
