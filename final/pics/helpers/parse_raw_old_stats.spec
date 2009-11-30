require 'parse_raw_old_stats'

require 'spec/autorun'

describe Parser do


it 'should parse dt lines' do

   deaths = "
Doing stats on runs runs just numbers do_dts_take6_at0.1_run1_of_2_major_2_of_12do_dts_take6_at0.1_run2_of_2_major_2_of_12
death methods
dR 109.0 dT 794.5 http_straight 0.0"


   a = Parser.parse deaths
  a['death methods'].should == {0.1 => {'dR' => 109.0, 'dT' => 794.5, 'http_straight' => 0.0}}
  

end

  it "should translate well" do  
    hash = {}
    hash[1.0] = {"dR" => 0.0, 'dT' => 1.0}
    hash[2.0] = {'dR' => 1.0, 'dT' => 1.0}
    ParseRaw.translate_conglom_hashes_to_lined_hashes(hash).should == {'dR' => [[1.0, 0.0], [2.0, 1.0]], 'dT' => [[1.0, 1.0], [2.0, 1.0]]}
  end


end

describe P2PPlot do


 it "should be able to take a hahs and calculate minimum x values from it as if it were graph lines" do
 
   P2PPlot.get_smallest_x({'abc' => [[1,1], [1,2]]}).should == 1
   
 end
 
 it "should generate a graph" do
   File.delete 'name.pdf' if File.exist? 'name.pdf'
   P2PPlot.plotNormal 'x label', 'y label', {'abc' => [[1,1], [2,2], [3,3]]}, 'name.pdf'
   assert File.exist? 'name.pdf'
 end
 
 
  it "should generate a delete_cause graph" do
    Dir.chdir 'test' do
      ParseRaw.go 'raw_example.txt'
      assert File.exist? 'death_reasons.pdf'
    end
  end

   


end
