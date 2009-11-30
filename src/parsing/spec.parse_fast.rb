require 'spec/autorun'
require 'parse_fast'
require 'sane'

describe ParseFast do

  def go extra = nil
    subject = ParseFast.new 'test/peer_number_88_start_6.068199.log.txt'
    out = subject.go extra
  end

  it "should return a hash" do
    out = go
    out.should be_a(Hash)
  end

  it "should return download times within its output hash" do
    out = go
    out.should include(:download_time) # ltodo: should calculate it right :)
  end

  it "should tell you various stats" do
    out = go "6.339[88]BM (33141):cs straight download  [128.187.223.211:7778 => my:47453]: :just received 1368B (raw)"
    _dbg
    out[:all_cs_bytes].should == 1368
    out[:p2p_bytes].should == 0
  end


end
