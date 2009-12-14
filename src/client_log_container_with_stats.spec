require 'client_log_container_with_stats.rb'
require 'tempfile'

describe ClientLogContainerWithStats do

  it "should work if fileized" do
    a = ClientLogContainerWithStats.allocate
    a.instance_variable_set :@allReceivedP2P, ['abc', 'def']
    a.fileize_yourself
    a.allReceivedP2P.should == ["abc", "def"]
  end

  it "should work if not fileized..." do
    a = ClientLogContainerWithStats.allocate
    a.instance_variable_set :@allReceivedP2P, ['abc', 'def']
    #a.fileize_yourself
    a.allReceivedP2P.should == ["abc", "def"]
  end
end
