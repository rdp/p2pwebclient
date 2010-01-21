require 'fileutils'

class File
  
  if RUBY_PLATFORM =~ /mingw|mswin/
    FileUtils.touch 'temp_file'
    @@loc = 'temp_file'
  else
    @@loc = '/dev/random'
  end
  @@saver_file = File.new @@loc, 'r'
  
  def self.append_to to_this_file, data
    begin
      to_this = File.new to_this_file, 'a+'
      size = to_this.write data
      to_this.close
      raise 'bad'unless size == data.length
      return size
    rescue => e
      print "EMERGENCY WRITE to #{to_this_file} #{e}\n"
      begin
        @@saver_file.close
        to_this = File.new to_this_file, 'a+'
        length = to_this.write data
        to_this.close
        raise 'bad' unless length == data.length
        return length
      rescue => e
        print "FATAL FAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAIL"*10 + e.to_s
        raise
      ensure
        @@saver_file = File.new @@loc, 'r'
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
