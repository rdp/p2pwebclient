require 'spec/autorun'
require 'rubygems' if RUBY_VERSION < '1.9'
require 'sane'
require_relative '../constants'

describe LongRunningProxy do

  before do
    LongRunningProxy.go_own_thread
  end
  
  after do
    EM.stop
  end
    
  it "shouldn't barf on non existent files" do
    a = `curl http://ll:8888/bad.host`
  end 
  
  it "shouldn't barf on 302's" do
    a = `curl http://ll:8888/google.com`
  end  

  it "should return 301/302's right"
  

  it "should get normal files right"

  context "a 302 that returns text" do
    it "should return the text, too"
  end

  context "a 302 that returns size 0" do
    it "should return size 0"
  end

end
