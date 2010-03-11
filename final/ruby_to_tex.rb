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
  def translate string, filename_long
    filename = filename_long.gsub('.erb.tex', '.tex')     
    puts 'writing to', filename
    File.open(filename, 'w') do |f|
      result = (ERB.new string).result(binding)
      f.write("% auto-generated !!!!\n" + result)
    end
    File.read(filename)
  end


=begin
\begin{figure*}
  \begin{center}
    \subfigure[Download times]{
      \includegraphics[width=7cm]{pics/vr_medium_p2p_load_tak4/client_download_Percentile_Line.pdf}
      \label{figs:yanc_download_times}
    }     
    \subfigure[Load on the origin server]{
      \includegraphics[width=7cm]{pics/vr_medium_p2p_load_tak4/server_speed_Percentile_Line.pdf}
      \label{figs:yanc_server_load}
    }
    
    \subfigure[CDF of percent of file received from peers] {
      \includegraphics[width=7cm,]{pics/vr_medium_p2p_load_tak4/percent_from_clients_Percentile_Line.pdf}
      \label{figs:yanc_from_client_percentile}
    }
    
    \caption{P2P Download}
  \end{center}
\end{figure*}


=end

  #
  # options :label (like vary_dt), :caption (like "Vary T")
  # use like subfig:vary_dt_download_times
  # subfig:vary_dt_cdf_from_peers
  # subfig:vary_dt_origin_server_load
  # wanted_pics is like {'download_times' => true, 'origin_server_load' => true, 'death_reasons' => true, 'cdf_from_peers' => true, 'dht_puts' => true}
  def figure_directory dir_name, label_prefix, caption, wanted_pics = {'download_times' => true, 'origin_server_load' => true}
    
    dir_name = 'pics/' + dir_name
    
    raise 'need 1.9\'s ordered hashes...' unless RUBY_VERSION >= '1.9.0' 
    
    names = {}
    
    if wanted_pics['download_times']
      names['client_download_Percentile_Line.pdf'] = ['Download times', 'download_times']
    end
    
    if wanted_pics['origin_server_load']
      names['server_speed_Percentile_Line.pdf'] = ['Load on the origin server', 'origin_server_load']
    end
    
    if wanted_pics['death_reasons']
      names['death_reasons.pdf'] = ['Cause of transition to P2P download', 'death_reasons']
    end
  
    if wanted_pics['cdf_from_peers']
      names['percent_from_clients_Percentile_Line.pdf'] = ['Percent of File received from peers', 'cdf_from_peers']
    end
    
    if wanted_pics['dht_puts']
      names['dht_Put_Percentile_Line.pdf'] = ['DHT Put times', 'dht_puts']
    end
    
    sum = 
    "\\begin{figure*}" + 
      "\\begin{center}"

    for filename, (description, label) in names
      options = {}
      options[:subfigure] = true
      options[:label] = 'fig:' + label_prefix + '_' + label
      options[:caption] = description
      sum += (figure dir_name + '/' + filename, options).indent
    end
    
    sum += "
    \\caption[]{#{caption}}
    \\label{fig:#{label_prefix}}
    \\end{center}
    \\end{figure*}"
      
    #sum += "\n\\clearpage\n" # avoid annoying 'too many floating points' errors
    # yet it took up too much space though...
  end

  #attempt to create a nicely embedded picture, a la
  #\begin{figure} \begin{center} ...
  #
  def figure filename, options
    options[:caption] ||= '' # always need at least a blank caption...
    options[:width] ||= '6.5cm'

    figure = "figure"
    if options[:subfigure]
      beginning = "\n\\subfigure[#{options.delete(:caption).gsub('_', "\\_")}] {\n"
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
