require 'erb'
#
# translates a .erb file to latex :)
# note--if you want subfigures then at the very beginning of your latex file you'll want to \include{subfigure}
#
# Helper methods
#
# doctest: String#indent
# >> 'abc'.indent
# => ' abc'
# >> "abc\ndef\nyo".indent
# => " abc\n def\n yo"
class String
  def indent
    all = ''
    self.each_line do | line |
  	  all << ' ' << line
    end
    all
  end
end

class RubyToTex
  # translate something.abc to something [tex]
  def translate string, file_name_long
  	File.open(file_name_long.split('.')[0..-2].join('.'), 'w') do |f|
	        result = (ERB.new string).result(binding)
  		f.write("% auto-generated !!!!\n" + result)
  	end
  end

  def figure_directory dir_name, options
    sum = ''
    for filename in Dir.glob(dir_name + '/*.{png,jpg,PNG,JPG}') do # not sure if those are necessary
      name = filename.split('_')[0..-2].join(' ')
      options[:caption] = options[:caption_prefix] + name
      sum += figure filename, options
    end

#    sum += "\\label{#{options[:label]}}\n"
    sum += "\n\\clearpage\n" # avoid annoying 'too many floating points' error

    sum
  end

  #attempt to create a nicely embedded picture, a la
  #\begin{figure} \begin{center} ...
  #
  def figure filename, options
         options[:caption] ||= '' # always need at least a blank one
         options[:width] = '80mm' unless options.has_key? :width
	 options[:filename] = filename
    	"\\begin{figure}[htp]\n" + 
    	     self.picture_options(options).indent +
        "\\end{figure}\n"
    end

    def picture_options options
  	if options[:center]
  	   options.delete(:center)
  	   "\\begin{center}\n" + 
  	      picture_options(options).indent + 
        "\\end{center}\n"
	 
  	elsif(options[:filename])
  	   filename = options.delete(:filename)
  	   "\\includegraphics[" +
              (options[:width] ? "width=#{options[:width]}," : '') + 
              (options[:height] ? "height=#{options[:height]}" : '') + 
              "]{#{filename}}\n" +  picture_options(options)
	elsif options[:caption]
	   caption = options.delete(:caption)
   	   "\\caption{#{caption}}\n" + picture_options(options)
        elsif options[:label]
  	   label = options.delete(:label)
  	   "\\label{#{label}}\n" + picture_options(options)
        else
  	   ''
  	end 
  end
         

end

for arg in ARGV do
  RubyToTex.new.translate(File.read(arg), arg)
end

if ARGV.length == 0 or ARGV.include? '-h' or ARGV.include? '--help'
 puts "usage: #{$0} filename.tex.erb or whatever you want to call it--it strips the last suffix and writes to that"
end
