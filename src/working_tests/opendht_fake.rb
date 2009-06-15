require 'working_tests/opendht_tests.rb'

class TestFake < Test::Unit::TestCase
  include OpenDHT_Tests
  def get_right_class
    OpenDHTEMFake
  end
end
