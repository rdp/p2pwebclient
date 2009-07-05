=begin
doctest: parses a conjunto right
>> all = "Doing stats on runs runs just numbers unnamed316651_at25_run1unnamed316651_at25_run2\ndownload times %'iles'\n61.51 161.8 352.64 560.03 992.02"
>> parse(all)
=> {'download times' => {25.0 => [61.51, 161.8, 352.64, 560.03, 992.02]}}
>> puts "\n\n\n\n\n", parse( File.read 'test/raw_example.txt').inspect
=end


def parse large_string
 setting = nil
 name = nil
 numbers = nil

 number_regex = '(\d+\.\d+|\d+) '
 five_numbers = Regexp.new((number_regex * 5).strip)
 all = {}

 large_string.each_line {|line|
   puts 'processing line', line
   if line =~ /_at(\d+)_/
     setting = $1.to_f
   elsif line =~ /(^.*) %'iles'/ # percentiles
     name = $1
   elsif line =~ five_numbers
     puts 'got good'
     numbers = [$1.to_f, $2.to_f, $3.to_f, $4.to_f, $5.to_f]
   end

   puts "\n\n\n", 'line', line, 'name', name, 'setting', setting, 'numbers', numbers
   if name and setting and numbers
      all[name] ||= {}
      all[name][setting] = numbers
      name = numbers = setting = nil
    end
 
 } 
 all

end
