require 'spec'
require 'lib/hash_set_operators'

describe Hash do
  describe "when +'ing" do
    it "another hash should behave like a.merge(b)" do
      result = {:controller => :user, :action => :edit} + {:action => :show, :id => 1}
      result.should == {:controller => :user, :action => :show, :id => 1}
    end

    it "an array, should throw an exception" do
      lambda { {:controller => :user, :action => :edit} + [:action] }.should raise_error
    end
  end

  describe "when -'ing" do
    it "another hash should behave like the keys from the second hash were ripped out of the first" do
      result = {:controller => :user, :action => :edit} - {:action => :show, :id => 1}
      result.should == {:controller => :user}
    end

    it "an array, should throw an exception" do
      lambda { {:controller => :user, :action => :edit} - [:action, :id] }.should raise_error
    end
  end

  describe "when &'ing" do
    it "another hash should retain only the key/value pairs from the first hash that share the same keys as the second hash." do
      result = {:controller => :user, :action => :edit} & {:action => :show, :id => 1}
      result.should == {:action => :edit}
    end

    it "an array, should throw an exception" do
      lambda { {:controller => :user, :action => :edit} & [:action, :id] }.should raise_error
    end
  end
end
