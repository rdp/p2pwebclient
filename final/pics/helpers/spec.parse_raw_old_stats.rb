require 'faster_rubygems' if RUBY_VERSION < '1.9'
require 'faster_require'
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
  
  before(:all) do
    Dir.chdir 'test' do
      @all = ParseRaw.go '../raw_example.txt'
      assert File.exist? 'death_reasons.pdf'
    end    
  end


  it "should generate a delete_cause graph" do
    # done before now
  end
  
  it "should yield a hard coded yname" do
    @all[0].yname.assoc("yrange")[1].should == "[0:180]" # max of 180s 
    #require '_dbg'
    @all[1].yname.assoc("yrange")[1].should == "[0:400000]" # max of 400K
    
  end

end
