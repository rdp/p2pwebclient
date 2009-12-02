stats = eval File.read('../yanc_30mb/yanc_30mb_3.stats.txt')
puts stats

# all_cs_bytes, p2p_p2p

all = stats.map{|file| 

  total = file[:all_cs_bytes] + file[:p2p_p2p]

  if file[:download_time]
    total = file[:p2p_p2p].to_f/total
    sputs 'total percent is', total, 'for file', file.inspect
    [total, file[:filename]]
    total
  end
}.compact.sort.map.with_index{|v, i| [i, v]}

puts all

require 'gnuplot_percentiles.rb'

P2PPlot.plotNormal :xlabel => 'Number of Peers', :ylabel => 'Percentage of File via P2P', :hash_values => {'CDF' => all}, :name => 'yanc_30_mb_cdf.pdf'


  