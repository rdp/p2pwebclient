require 'spec/autorun'
require 'parse_fast'

describe ParseFast do

  def go
    subject = ParseFast.new 'test/peer_number_88_start_6.068199.log.txt'
    out = subject.go
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
    out = go
    puts out
    out[:all_cs_bytes].should == 1368
    out[:p2p_bytes].should == 0
  end


end
