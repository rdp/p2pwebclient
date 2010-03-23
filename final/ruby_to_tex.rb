require 'erb'
#
# translates a .erb file to latex :)
# note--if you want subfigures then at the very beginning of your latex file you'll want to \include{subfigure}
#
# Helper methods
=begin
 doctest: String#indent
 >> 'abc'.indent
 => ' abc'
 >> "abc\ndef\nyo".indent
 => " abc\n def\n yo"
=end

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
  def translate string, filename_long
    filename = filename_long.gsub('.erb.tex', '.tex')     
    puts 'writing to', filename
    File.open(filename, 'w') do |f|
      result = (ERB.new string).result(binding)
      f.write("% auto-generated !!!!\n" + result)
    end
    File.read(filename)
  end

  # options :label (like vary_dt), :caption (like "Vary T")
  # use like subfig:vary_dt_download_times
  # subfig:vary_dt_cdf_from_peers
  # subfig:vary_dt_origin_server_load
  # wanted_pics is like 
  # {'download_times' => true, 'origin_server_load' => true, 'death_reasons' => true, 'cdf_from_peers' => true, 'dht_puts' => true}
  def figure_directory dir_name, label_prefix, caption, wanted_pics = {'download_times' => true, 'origin_server_load' => true}
    
    all_map = {}
    all_map['download_times'] = ['client_download_Percentile_Line.pdf', 'Download times']
    all_map['origin_server_load'] = ['server_speed_Percentile_Line.pdf', 'Load on the origin server']
    all_map['death_reasons'] = ['death_reasons.pdf', 'Cause of transition to P2P download']
    all_map['cdf_from_peers'] = ['percent_from_clients_Percentile_Line.pdf', 'Percent of File received from peers']
    all_map['dht_puts'] = ['dht_Put_Percentile_Line.pdf', 'DHT Put times']
    
    raise 'require 1.9\'s ordered hashes...' unless RUBY_VERSION >= '1.9.0'
    desired = []
    for wanted_pic, true_value in wanted_pics
      desired << [wanted_pic, all_map[wanted_pic]].flatten
    end
    dir_name = 'pics/' + dir_name    

    sum = 
    "\\begin{figure*}" + 
      "\\begin{center}"
    for name, filename, description in desired
      # add subfigures
      options = {}
      options[:subfigure] = true
      options[:label] = 'fig:' + label_prefix + '_' + name
      options[:caption] = description
      sum += (figure(dir_name + '/' + filename, options)).indent
    end
    
    sum += "
    \\caption[#{caption}]{#{caption}}
    \\label{fig:#{label_prefix}}
    \\end{center}
    \\end{figure*}"
      
  end

  #attempt to create a nicely embedded picture, a la
  #\begin{figure} \begin{center} ...
  #
  def figure filename, options
    options[:caption] ||= '' # always need at least a blank caption...
    options[:width] ||= '7.5cm'

    figure = "figure"
    if options[:subfigure]
      caption = options.delete(:caption).gsub('_', "\\_")
      beginning = "\n\\subfigure[#{caption}] {\n"
      ending =  "}"
    else
      beginning = "\\begin{figure}[htp]\n"
      ending =  "\\end{#{figure}}\n"
    end

    options[:filename] = filename
    beginning + self.picture_options(options).indent + ending
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

if ARGV.length == 0 or ARGV.include? '-h' or ARGV.include? '--help'
  puts "usage: #{$0} filename.tex.erb or whatever you want to call it--it strips the last suffix and writes to that"
else
  for arg in ARGV do
    RubyToTex.new.translate(File.read(arg), arg)
  end
end
