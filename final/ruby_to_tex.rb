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
    filename = file_name_long.split('.')[0..-2].join('.')
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
  # use like vary_dt_download_times
  # vary_dt_cdf_from_peers
  # vary_dt_origin_server_load
  def figure_directory dir_name, label_prefix, caption_prefix

    names = {'server_speed_Percentile_Line.pdf' => ['Load on the origin server', 'origin_server_load'],
      'client_download_Percentile_Line.pdf' => ['Download times', 'download_times'],
    'percent_from_clients_Percentile_Line.pdf' => ['CDF of percent of file received from peers', 'cdf_from_peers']}

    sum = 
    "\\begin{figure*}" + 
      "\\begin{center}"

    for filename, (description, label) in names
      options = {}
      options[:caption] = caption_prefix + " " + description
      options[:subfigure] = true
      options[:label] = label_prefix + '_' + label
      sum += figure dir_name + '/' + filename, options
    end
    
    sum += "\\end{center}" + 
      "\\end{figure*}"
      
    #sum += "\n\\clearpage\n" # avoid annoying 'too many floating points' errors
  end

  #attempt to create a nicely embedded picture, a la
  #\begin{figure} \begin{center} ...
  #
  def figure filename, options
    options[:caption] ||= '' # always need at least a blank caption...
    options[:width] ||= '70mm'

    figure = "figure"
    if options[:subfigure]
      beginning = "\n\\subfigure[#{options.delete(:caption).gsub('_', "\\_")}] {\n"
      ending =  "}"
    else
      beginning = "\\begin{figure}[htp]\n"
      ending =  "\\end{#{figure}}\n"
    end

    options[:filename] = filename
    #_dbg
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
