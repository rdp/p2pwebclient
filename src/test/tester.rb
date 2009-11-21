# this is an old test bank for the project -- see working_tests now
require './p2p_client'
require './lib/ruby_useful_here.rb'
require 'cs_and_p2p_client.rb'
require 'socket'
require 'driver'
require 'test/unit/ui/console/testrunner'
require 'server_unit_tests.rb'

require 'lib/test_useful.rb'

if clientHasGraphLibraries
  require 'singleMultipleGraphs.rb'
end

# ltodo make sure that the 'test servers quit' tests only wait like one second max :)

# ltodo take out all debug output 's that I no longer need :)
# ltodo a test that is 'make sure they finished pretty fast with such and such [http, p2p] ... :)
class Tester
  def Tester.goSingle
# Test::Unit::UI::Console::TestRunner.run(P2P_Server_Tests)
# Test::Unit::UI::Console::TestRunner.run(TestUseful)
# usefulTestSelf # ruby useful
  Test::Unit::UI::Console::TestRunner.run(DriverTester)
#Driver.timeSelf
#  CSP2PGetter.testSelf
#SingleLogParser.testSelf
#  IndividualGraph.testSelf
#  TextLines.testSelf   
#  RunGrapher.testSelf
#  PercentileGraph.testSelf
#   BlockManager.testSelf
##  ltodo add driver with trivial run...hmm. maybe far later :)
#ClientLogContainerWithStats.testSelf
#  LineWithPointsFile.testSelf
#  PointLine.testSelf

#TimeKeeper.testSelf
begin 
#print "testing opendht gingerly\n";  OpenDHT::Hash.testSelf;  
	rescue => detail; print "ACK OPENDHT itself failed!" + detail.to_s + detail.class.to_s + detail.backtrace.join("...") ; end
#  LocalDriveDHT.testSelf # OpenDHTWrapper.testSelf(LocalDriveDHT)
#OpenDHTWrapper.testSelf(OpenDHT::Hash)
  # ltodo do not use dhtClassToUse anywhere :)
#  Listener.testSelf
#  GraphHelper.testSelf
#  print "all tests end!"
#   VaryParameter.testSelf    
exit 0
  end
  # ltodo tell Ruby it appears that raised errors do not report the point they were raised at within the code
# ltodo optimize it with a 10 peers and a one byte/sec server local.

 def Tester.all
  Test::Unit::UI::Console::TestRunner.run(P2P_Server_Tests)
  Test::Unit::UI::Console::TestRunner.run(TestUseful)
  Test::Unit::UI::Console::TestRunner.run(DriverTester)
  
  CSP2PGetter.testSelf
  BlockManager.testSelf
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

if debugMe('tester') # strip that off if there
    print "I would have run anyway!"
end
if ARGV.length > 0 
  assert ARGV[0] == "all"
  Tester.all
else
  Tester.goSingle
end
# ltodo after running tester check for stray threads
# ltodo rangeerror where was that... :)
# ltodo compare me with wget ha ha :)

# our own DHT setting for testing only

# ltodo tell 'ruby xmlrpc is too stringent
# ltodo change tests to standard ruby unit tests :)
# ltodo rexml thing weird just report fix I guess...1
# ltodo optimize with localdrivedht wait 0 -- it should FLY
# ltodo super optimize sending to self 10MB file
#