incoming = File.read ARGV[0]
out = ""
incoming.each_line{|l|
  if l.length > 150
    words = l.split(" ")
    in_chunk = 0
    words.each{|w|
      out << w << " "   
      in_chunk += w.length
      if in_chunk >= 80
        out << "\n"
        in_chunk = 0
      end
    }    
  else
    out << l
  end
}
puts out
# to test, run this file against itself
# aaaa  aaa  aaa  aaaaa aaaa a      aaaa  aaa  aaa  aaaaa aaaa a aaaa  aaa  aaa  aaaaa aaaa a aaaa  aaa  aaa  aaaaa aaaa a aaaa  aaa  aaa  aaaaa aaaa a aaaa  aaa  aaa  aaaaa aaaa a aaaa  aaa  aaa  aaaaa aaaa a aaaa  aaa  aaa  aaaaa aaaa a aaaa  aaa  aaa  aaaaa aaaa a aaaa  aaa  aaa  aaaaa aaaa a aaaa  aaa  aaa  aaaaa aaaa a aaaa  aaa  aaa  aaaaa aaaa a aaaa  aaa  aaa  aaaaa aaaa a aaaa  aaa  aaa  aaaaa aaaa a aaaa  aaa  aaa  aaaaa aaaa a aaaa  aaa  aaa  aaaaa aaaa a  