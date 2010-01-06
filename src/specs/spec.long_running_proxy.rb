require 'spec/autorun'
require 'rubygems' if RUBY_VERSION < '1.9'
require 'sane'
require_relative '../constants'

describe LongRunningProxy do

  it "shouldn't barf on non existent files"

  it "should return 301/302's right"

  it "should get normal files right"

  context "a 302 that returns text" do
    it "should return the text, too"
  end

  context "a 302 that returns size 0" do
    it "should return size 0"
  end

end
