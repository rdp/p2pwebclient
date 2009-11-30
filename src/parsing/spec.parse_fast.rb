require 'spec/autorun'
require 'sane'
require_rel 'parse_fast'

describe ParseFast do

  def go extra = nil
    subject = ParseFast.new File.dirname(__FILE__) + '/test/peer_number_88_start_6.068199.log.txt'
    out = subject.go extra
  end

  it "should return a hash" do
    out = go
    out.should be_a(Hash)
  end

  it "should return download times within its output hash" do
    out = go
    out.should include(:download_time) # ltodo: should calculate it right :)
    out[:filename].should include('test/peer_number_88_start_6.068199.log.txt')
  end

  it "should tell you various stats" do
    out = go "6.339[88]BM (33141):cs straight download  [128.187.223.211:7778 => my:47453]: :just received 1368B (raw)"
    out[:all_cs_bytes].should == 1368
    out[:cs_straight].should == 1368
    out[:p2p_p2p].should == 0
  end


  it "should parse p2p p2p bytes" do
    out = go "453.770[88]BM (33141):p2p p2p download Block 26 [128.223.8.112:14921 => my:47411]: :just received 13488B (raw)"
    out[:p2p_p2p].should == 13488
  end

  it "should parse p2p cs bytes" do
    out = go "827.916[88]BM (33141):p2p cs origin download Block 77 [128.187.223.211:7778 => my:37137]: :just received 13680B (raw)"
    out[:p2p_p2p].should == 0
    out[:cs_p2p].should == 13680
  end


end
