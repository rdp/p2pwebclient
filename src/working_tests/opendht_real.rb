require 'working_tests/opendht_tests.rb'

class TestReal < Test::Unit::TestCase
  include OpenDHT_Tests
  def get_right_class
    OpenDHTEM
  end
end
