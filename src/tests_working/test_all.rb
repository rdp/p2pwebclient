require 'test/unit'
require 'test/unit/ui/console/testrunner'

at_exit {
  if $!
    puts "==== "
    puts $!.backtrace.join("\n")
    puts "===="
  end
}

require File.dirname(__FILE__) + '/../constants'
require_rel '*.rb' # listener_tests, etc.



# ltodo make sure that the 'test servers quit' tests only wait like one second max :)

# ltodo take out all debug output 's that I no longer need :)
# ltodo a test that is 'make sure they finished pretty fast with such and such [http, p2p] ... :)
class Tester
  # ltodo tell Ruby it appears that raised errors do not report the point they were raised at within the code
  # ltodo optimize it with a 10 peers and a one byte/sec server local.
  # ltodo: optimizations: from emails, from stickies

  def Tester.all
    Test::Unit::UI::Console::TestRunner.run BMTester
    Test::Unit::UI::Console::TestRunner.run TestReal
    Test::Unit::UI::Console::TestRunner.run Listener_Tests
    #Test::Unit::UI::Console::TestRunner.run TestFake
    Test::Unit::UI::Console::TestRunner.run ServerTester
    Test::Unit::UI::Console::TestRunner.run TestNextTick
    Test::Unit::UI::Console::TestRunner.run TestUseful

    # not done BlockManager.testSelf
    usefulTestSelf
    TimeKeeper.testSelf
    print "testing opendht gingerly\n"
    begin
      OpenDHT::Hash.testSelf
    rescue => detail
      print "ACK OPENDHT itself failed!" + detail.to_s + detail.backtrace.join("...")
    end
    LocalDriveDHT.testSelf # which is   OpenDHTWrapper.testSelf(LocalDriveDHT)
    OpenDHTWrapper.testSelf(OpenDHT::Hash)
    #  $dhtClassToUse = HangingDHT # ltodo maybe the 'wait 60 seconds then returns' dht :)
    Listener.testSelf
    if clientHasGraphLibraries
      # graphing
      Hash.testSelf # ltodo check -- is this just graph related? test it there
      TextLines.testSelf
      SingleLogParser.testSelf
      IndividualGraph.testSelf
      MultipleRunsSameSettingGrapher.testSelf
      PercentileGraph.testSelf
      LineWithPointsFile.testSelf
      ClientLogContainerWithStats.testSelf
      PointLine.testSelf
      SingleLogParser.testSelf
      GraphHelper.testSelf
      VaryParameter.testSelf
    end
    Driver.testSelf
    print "\nall tests end!!"
  end
end

if File.expand_path($0) ==File.expand_path( __FILE__ )
  print "I run no matter what muhaha"
else
 raise 'dont require this file' + $0
end

Tester.all


# ltodo after running tester check for stray threads
# ltodo rangeerror where was that... :)
# ltodo compare me with wget ha ha :)

# our own DHT setting for testing only

# ltodo tell 'ruby xmlrpc is too stringent
# ltodo change tests to standard ruby unit tests :)
# ltodo rexml thing weird just report fix I guess...1
# ltodo optimize with localdrivedht wait 0 -- it should FLY
# ltodo super optimize sending to self 10MB file