#!/usr/bin/env ruby
# ltodo profile whole thing :)
# todo: skip some of the graphs--who cares...except there are some stats in there that aren't shown in vary parameter graphs yet--single things. Leave them :)
# ltodo: still figure out more 'tight' close stats--does graphing graphing take forever?
# ltodo better TTL maybe...5hr. total
require 'resolv-replace'
require 'optparse'
require './constants'
require_rel 'cs_and_p2p_client', 'server_slow_peer.rb', 'listener', 'lib/ruby_useful_here', 'listener'

# require 'facets' # just for driver :)
# ltodo improvement don't just save file size header info on the DHT, save more :)

$shouldDoGraphsSingle = true # ltodo move down
$shouldDoVaryParameterGraphs = true

load 'constants.rb'
require 'benchmark'
require 'forky'

require 'forky_replacement_fake.rb' # had enough with the pauses...

if clientHasGraphLibraries # ltodo with driver it sends the 'old old' time when it finally fires 'em
  require 'multiple_runs_same_setting_grapher.rb'
  require 'vary_parameter_graphs.rb'
else
  print "ack no graphing libraries! will not be creating anything!"
  raise 'no graphing libs'
  $shouldDoGraphsSingle = false
  $shouldDoVaryParameterGraphs = false
end

$doIndividuals = false

# ltodo run it 'without' CS (since we DO have CS in there already!) -- should be fastest!
class Thread
  def wait_till_dead this_many_seconds = 60, kill = true
    start_time = Time.now
    while (Time.now - start_time < this_many_seconds) && self.alive?
      sleep 0.5
    end
    Thread.kill(self) # we're actually killing it [believe it or not] from a different thread so this is ok.
  end
end

# note could us elogarithmic backoff with setting, too
# ltodo writeup the thing was problematic because it can become clogged with distant, slow peers, and sometimes removes don't work on the DHT., and there is a race problem to set it up.  This could use more work.

# ltodo proxies or communiation within the DHT for 'you're within a NAT--come to me!' ha ha :)
# ltodo optimization is 'loose' block boundaries--just keep flooding me!
# ltodo check out some random vers ions, see if testing is faster within them. If so, why?
# ltodo with vary parameter print out the sum of uploaded server vs. peers, for my benefit :)
# ltodo may want to do multi-file from here (seems more realistic, somehow)
class Driver
  @@test = false
  @@useWBO = false
  @@useSpecificHost = false
  @@useLocalHostAsServer = false
  @@useArbitraryListener = nil
  @@peersPurged = nil
  @@dT = 1.0 # tlodo have this adjusted to 'mean' skip CS very low means skip CS
  # ltodo optimization -- if on original HTTP and NONE are listed (like for first block or the size is not even listed in the DHT then do NOT give up no matter what...that's an interesting case because theoretically could spawn some new p2p clients to look, though...ltodo later
  peer_per_second_entering = 15
  @@spaceBetweenNew = 1.0/peers_per_second_entering = 15 # note you'd want to increase this if you set fake start
  use_peer_total = true
  unless use_peer_total # else use seconds_for_the_run
    seconds_for_the_run = 60
    @@numClientsToSpawn = seconds_for_the_run/@@spaceBetweenNew
  else
    @@numClientsToSpawn = 1000
  end
  @@linger = 10
  @@fileSize = 100.kb
  @@serverBpS = 255.kbps
  @@dR = 125.kb#@@serverBpS*0.9
  @@peerTokens = 5 # as per Dr. Z's email :) tough to tell, though...very tough...almost might want unlimited!
  @@dW = 2.00 # you probably want this greater than @@dT, though it starts the window only after dT is passed.
  @@blockSize = 100.kb
  @@fakeStartWaitAsSeconds = nil#20
  #$PRETEND_CLIENT_SERVER_ONLY = false # do we actually pass this out to the new clients? if so then remove from constants :) ltodo cleanup
  #$useOriginRevertOptimization edit in constants.rb, re-sync via SVN
  #$LOCAL_PEERS_OK = false #  edit in constants, do svn sync if desired
  @@multiples_variant_possibilities = ["linger", "smallTest", "teenyTest", "peersPerSecondCS", "dT", "peersPerSecondP2P", "dR", "dW", "multipleFiles", "multipleFilesCS", 'blockSize', 'serverBpS', 'bitTorrent', 'largeFile']
  @@howManySubRepetitions = 4 # meaning how many times to repeat each test, holding all the factors constant
  # ltodo double check that our generator doesnt' sometimes come down by a factor of 10, and it works well for all numbers (yuck)
  @@actuallyPerformMultipleRuns = true

  def Driver.initializeVarsAndListeners peerFileName = nil, execThis = nil# ltodo umm...this class is ugly!
    # right now it uses these for directory names, and then just arbitrarily download the file (size, file) given by @@fileUrl
    #[ltodo move here] [i.e. file SIZE itself dictated by constants.rb, still]

    # note that the multiples stuff is different than that here--I think.  At least numClientsToSpawn

    eval(execThis) if execThis

    recalculateCurrentGlobalUrl @@fileSize

    if @@fakeStartWaitAsSeconds
      @@numClientsToSpawn -= 2
    end

    ## oooh ltodo make the globals into Driver defaults! read them from here!
    if $PRETEND_CLIENT_SERVER_ONLY # edit in constants
      @@dT = 1E6.to_i
      @@dW= 1E6.to_i
      @@linger = 0
      assert $p2pSkipCS == false
    end

    eval(execThis) if execThis

    host = Socket.gethostname
    @@peers = []
    if @@useLocalHostAsListener
      print "using localhost for listeners\n"
      $allListenersPort.upto($allListenersPort + 9 ) do |n|
        @@peers << ['127.0.0.1',n]
      end
    elsif @@useArbitraryListener
      host = @@useArbitraryListener
      print "using #{host} as only listener!\n"
      @@peers << [host, $allListenersPort]
    else
      if peerFileName
        print "using #{peerFileName} for peers"
        filename = peerFileName
      else
        filename = CacheName
        print "using cached peers for pl peers"
      end
      print "using file #{filename} for (non purged but then purged) peer list\n"
      running = nil
      begin
        running = File.new(filename, "r")
      rescue
        print "WARNING no peer file found! #{filename}"
      end
      running.each_line { | line|
        @@peers << [line.strip, $allListenersPort]
      } if running
    end
    # ltodo says 'server assumed' twice on driving
    @@allRunLogger = Logger.new("../logs/driver_all_output.txt", 0, "driver") # ltodo close

  end
  # ltodo that weird bug of 'ummm...it just drops us!' [the wireshark bug]
  # ltodo graph that has 'one setting' and 'other setting'
  # ltodo on vary parameter have it say how many clients total up front
  # ltodo say 'we had to get ALL the hosts -- future work writeup -- would be to get 'certainly' active hosts.
  @@useLocalHostAsListener = false
  @@grabPeerMutex = Mutex.new

  CacheName = "planetlab_alive_with_p2pweb_cached.txt"
  CacheNameRaw = "../distro/planetlab_hosts.txt.all.ips.txt"

  @@localAndForeignServerPort = 7778

  def self.servers_port
    @@localAndForeignServerPort
  end

  @@total_files_to_use = 1
  @@url_use_bittorrent = false

  def self.recalculateCurrentGlobalUrl fileSize
    if @@url_use_bittorrent
      @@fileUrl = 'http://bittorrent'
    else
      servers = {'planetlab1.flux.utah.edu' => '155.98.35.2', 'planetlab2.flux.utah.edu' => '155.98.35.3', 'planetlab1.byu.edu' => '128.187.223.211'}
      ip = servers['planetlab1.byu.edu']
      ip = '127.0.0.1' if @@useLocalHostAsServer
      assert ip
      url = "#{ip}:#{@@localAndForeignServerPort}"
      url = 'wilkboardonline.com/roger/p2p/test_files' if @@useWBO
      url = @@useSpecificHost if @@useSpecificHost
      final_urls = []
      @@total_files_to_use.times do |n|
        fileSize = 10_000 if n >= 1
        final_urls <<  "http://#{url}/#{fileSize/1000}K.file" + rand(10_000_000).to_s # ltodo dyn. index for both created...
      end
      @@fileUrl = final_urls.join(';')
    end
    print "setting url it to #{@@fileUrl} "
    @@fileUrl
  end

  def Driver.throwUpListener
    begin
      @@listenerObject, @@listenerThread = Listener.listen
    rescue
      print "ACK listener already running! hope it works! returning nil!"
      return nil
    end
    return @@listenerObject, @@listenerThread
  end

  def Driver.throwUpServer file_size_to_serve = 100.kb
    begin
      BlockManager.startPrefabServer @@fileUrl, :size => file_size_to_serve, :speed_limit => @@serverBpS
    rescue Exception => e
      print "UNABLE TO START LOCAL SERVER #{e}"
    end
  end

  def Driver.tearDownServer
    raise 'not implemented teardownserver'
  end
  # ltodo this file is mostly legacy--fix
  # ltodo: recreate bug as in: a multi-threaded self pounder that will try and cross sockets
  # and also: this very program with tons of overlap
  # also windoze

  def Driver.tearDownListener
    if @@listenerThread then
      @@listenerObject.stopBlocking
      @@listenerThread.join
    elsif @@listenerObject
      @@listenerObject.stopBlocking
      @@listenerObject = nil
    else
      print "listener was never alive? problematic for testing"
    end
  end

  def Driver.newFileName
    number = rand(100000) # ltodo use runName
    fileout = File.open("url_name", "w")
    fileout.write(number)
    fileout.close # legacy, but fast :)
    recalculateCurrentGlobalUrl @@fileSize
  end

  def Driver.runFromParsedArgs
    style = nil #[:single or :multiple]
    runName = multiples_variant = num_clients = linger = fileSize = blockSize = serverBpS = nil
    ARGV << '--help' if ARGV.length == 0
    Driver.initializeVarsAndListeners CacheName
    if ARGV.include? "--use_rev"
      print "USING REV"
      require 'lib/revem_here'
    end

    # handle --sanity-check in a hacky way
    if ARGV.include? '--sanity-check'
      ARGV << ['--do=versions', '--update_opendht_local_list', '--check_live_server']
      ARGV.flatten!
    end

    command_to_run_against_all_listeners = nil

    OptionParser.new do |opts|
      opts.banner = " p2pwebclient drier version #{$version} Usage: #{__FILE__}  options"

      opts.on('--use_rev', 'use Rev instead of EventMachine for the driver -- doesnt have timeouts, but it\'s there for use, but most likely broken at the moment') do
      end

      available_do_commands = ['restarts', "svnups", "breakpoints",
        "killEverythings", "versions","svnup_restarts", 'doneWithRun?s',
      'ruby_versions', 'delete_all_logss']
      opts.on('-d', '--do=STRING', "execute command to all listeners #{available_do_commands.inspect} [current local version is #{$version}]") do |command|
        raise 'poor command name -- did you forget a plural' unless command.in? available_do_commands
        command_to_run_against_all_listeners = command
        puts 'running:' + command
      end


      opts.on('--superStarts', 'hard kill and restart active plab listeners') do
        updateProc = Proc.new { |peer, port|
          print "failed to version ", peer, port, " -- superStarting \n\n\n"
          system("ssh byu_p2p@#{peer} \"p2pwebclient/hard_kill_and_restart_listener.sh\"")
          print "super restarted [hard restarted]", peer, port, "\n"
        }
        Driver.sendAllListeners("version", updateProc)
        exit 0
      end

      opts.on('--updateCache', 'update the cached list of live listeners on planetlab') do
        # I'm...not sure if this is working right for sure...
        @@useLocalHostAsListener = false
        Driver.initializeVarsAndListeners CacheNameRaw
        File.delete CacheName if File.exists? CacheName # start afresh
        writeTo = File.open(CacheName, "a")
        count = 0
        Driver.sendAllListeners("version") { |peer, port, answer|
          print "answer from #{peer} #{port} #{count += 1}\n\t=> #{answer}"
          if answer.include? "Rev:"
              writeTo.puts peer
          else
              puts 'ignored!'
          end
        }
        writeTo.close
        exit 0
      end


      opts.on('--sanity-check', 'make sure all is ready for tests -- runs some other tests from driver') {
        puts 'check your screen'
      }

      opendht_filename = 'alive_opendht_planetlab.txt.local'

      opts.on('--update_opendht_local_list', "refresh the local file #{opendht_filename} with active [private] opendht participants") do
        require 'lib/opendht/bamboo/known_gateways'
        hosts = $opendht_gateways
        success = 0
        for host, port in hosts
          begin
            port = port + 1 # tcp port
            a = TCPSocket.new host, port
            a.close
            success += 1
            print "good opendht gateway--at least the port's open: #{host}:#{port}\n"
          rescue Exception => e
            print "BAD OPENDHT MAIN SERVER #{host} #{port}...SNIFF...DOWN! #{e}\n\n"
          end
        end
        puts "\ngot #{success} out of #{hosts.length} main opendht hosts"

        latest_and_greatest = File.new opendht_filename, 'w'
        Driver.initializeVarsAndListeners CacheNameRaw

        number_done = 0
        number_success = 0
        count_successful_so_far = 0
        Driver.each_peer_host {|peer, port|
          opendht_port = 3632
          begin
            EM::connect( peer, opendht_port, SingleConnectionCompleted) {|conn|
              conn.connection_completed_block = proc {|conn|
                print "S";
                number_success += 1
                ip = conn.get_tcp_connection_info_hash[:peer_host]
                latest_and_greatest.write("#{count_successful_so_far += 1}:\t#{ip}:#{opendht_port}\n");
                conn.close_connection;
              }

              conn.unbind_block = proc {
                print "f"
                number_done += 1
              }
            }
          rescue RuntimeError => e
            print "runtime error #{e}\n"
            number_done += 1
          end
        }
        begin
          sleep 0.1 while number_done < Driver.peer_count
        rescue Interrupt
          print "rescued 1\n"
        end
        puts "\ngot #{success} out of #{hosts.length} main opendht hosts"
        puts "got successful opendht count: #{number_success}"
        latest_and_greatest.close
        puts "remember to copy #{opendht_filename} into lib/opendht/cached_all_gateways_file_name if you want to distribute the new list"
      end

      opts.on('--check_live_server', 'run wget to download a small file from the origin server we set it up as -- doesnt work in ilab :)') do
        `wget #{@@fileUrl}`
        exit
      end

      opts.on('--rsync_all_existing_logs') do
        Driver.rsyncAll
        exit 0
      end

      opts.on('--svnupAndRestartIfOlds', 'send an svn up and restart if necessary') do
        Driver.each_listener_as_thread { | peer, port|
          begin
            sockOut = TCPSocket.new(peer, port)
            sockOut.write("version")
            theirVersion = sockOut.recv(1024)
            sockOut.close
            if theirVersion.chomp != $version
              sockOut = TCPSocket.new(peer, port)
              sockOut.write("svnup_restart")
              resetAnswer = sockOut.recv(1024)
              sockOut.close
              print "reset #{peer}:#{port} -- they were at #{theirVersion.inspect}, we think #{$version.inspect} is better\n"
            else
              #             print "#{peer}:#{port} already have our version #{$version}"
            end
          rescue Exception => detail
            #          print "erred svnupifolding on", peer, port, "\n" + detail.class.to_s
          end
        }
        exit 0
      end

      opts.on('-a', '--num_clients=NUMBER', "number of clients to spawn per test -- a few tests ignore this, like BitTorrent default #{@@numClientsToSpawn}") do |num|
        num_clients = num.to_i # was nil
        raise 'poor client count number ' + num.to_s if num_clients < 1
      end

      opts.on('--listener_port=PORT_NUMBER', 'have all listeners contacted on that port') do |num|
        $allListenersPort = num.to_i
      end

      opts.on('--use_wbo', 'use wilkboardonline as server') do
        @@useWBO = true
      end

      opts.on('--use_specific_host=HOST', 'use this host as the root for files') do |host|
        @@useSpecificHost = host
        raise if host =~ /http/ or host !~ /\./
      end

      opts.on('--peer_tokens=NUMBER', "peer tokens is currently how many blocks simultaneously, with one peer MAX per block until it gets to the last block. Default #{@@peerTokens}") do | peer_tokens_string|
        @@peerTokens = eval(peer_tokens_string)
      end

      opts.on('--linger=SECONDS', "linger time for all peers -- default is #{@@linger}") do |linger|
        linger = linger.to_i
      end

      opts.on('--space_between_new=SECONDS', "space between each peer as they're fired off -- interval -- default #{@@spaceBetweenNew}s") do |space|
        @@spaceBetweenNew = eval(space)
      end

      opts.on('--local_server_speed=NUMBER', 'local server speed') do |num_string|
        serverBpS = eval(num_string) # ltodo we can just set them here, now, I think...change tehse to be @@serverbpS =
      end

      opts.on('--cs_only', 'run as if in cs mode only') do
        $PRETEND_CLIENT_SERVER_ONLY = true
      end

      opts.on('--block_size=SIZE', "block size -- default is #{@@blockSize}") do |block_size_string|
        blockSize = eval(block_size_string)
      end

      opts.on('--file_size=SIZE', "file size -- default is #{@@fileSize}") do |file_size_string|
        fileSize = eval(file_size_string)
      end

      opts.on('--use_local_listener', 'use local listener') do
        @@useLocalHostAsListener = true
      end

      opts.on('--use_arbitrary_listener=LISTENER_HOST_NAME', 'use the given listener--nothing else') do |listener|
        @@useArbitraryListener = listener
        puts 'using arbitrary listener' + listener
        if num_clients.nil?
            puts 'also running only one client'
           num_clients = 1
        end
      end

      opts.on('-p', '--do_multiples_with_variant=NAME', 'multiples variant ex: ' +  @@multiples_variant_possibilities.inspect + ' note that currently for multiples test you specify multiple, it does it twice with some absolutely hard coded values for what it is changing it from and to') do |name|
        multiples_variant = name
        style = :multiple
      end

      opts.on('--do_single_run', 'do a single test (1x1) with the defaults and the parameters you pass in') do
        style = :single
      end

      opts.on('--do_small_test_test', 'do a small variant test 2x2 -- smallTest with a nicer runname') do
        multiples_variant = 'smallTest'
        style = :multiple
        runName = 'small_test_' + rand(1000000).to_s
        @@amTesting = true
      end

      opts.on('--test', 'run quicker since you\'re a testin, not running a real run') do
        @@test = true
        ## TODO HERE!
      end

      opts.on('--dr=BYTES_PER_SECOND', 'dr rate') do |dr|
        @@dR = eval(dr)
      end

      opts.on('--dt=SECONDS', 'dt to wait') do |dt|
        @@dT = eval(dt)
      end

      opts.on('--use_local_server', 'Self explanatory') do
        @@useLocalHostAsServer = true
      end

      opts.on('--dw=SECONDS', 'dw window worth of seconds to "average" to calculate dR') do |dw|
        @@dW = eval(dw)
      end

      opts.on('--name=NAME', 'specify a name--if a single run then this name is used, if a multiple run then this name is the prefix followed by the current varying parameter and run number [like 2 out of 5]') do |name|
        raise 'name dislikes --s' if name.include? '--'
        runName = name
      end

      opts.on('--sub_repetitions_per_variant_setting=NUMBER', " default #{@@howManySubRepetitions}") do |subs|
        @@howManySubRepetitions = subs.to_i
        raise 'subs must be number' if @@howManySubRepetitions == 0
      end

      opts.on('--just_display_what_would_have_run_for_multiples_settings') do
        @@actuallyPerformMultipleRuns = false
      end

    end.parse!

    if !style.in?( [:single, :multiple]) && !command_to_run_against_all_listeners
      # if they passed us something else we don't want to continue
      print 'done, no run style specified'
      exit
    end

    Driver.initializeVarsAndListeners # sets up from globals
    # a few need to be set 'after' the rest so that they don't get nuked by a call to initializeVarsAndListeners
    # and now apply our own, in case they were setup 'for' us within the above.
    # ltodo: clean up this is no longer necessary

    if command_to_run_against_all_listeners
      command_to_run_against_all_listeners = command_to_run_against_all_listeners[0..-2] # strip the ending s's
      count = 0
      # we actually want to only use the 'live' peers for this since...they're the only ones listening to take the call!
      puts 'running ' + command_to_run_against_all_listeners
      Driver.sendAllListeners(command_to_run_against_all_listeners) { |peer, port, answer|
        print "answer from #{peer} #{port} #{count += 1}\n\t=> #{answer}"
      }

      puts 'exiting'
      exit(0)
    else
      puts 'no command'
    end


    @@numClientsToSpawn = num_clients if num_clients
    @@linger = linger if linger
    @@blockSize = blockSize if blockSize
    @@fileSize = fileSize if fileSize
    @@serverBpS = serverBpS if serverBpS

    # now do a real run of some type

    runName ||= 'unnamed' + rand(1000000).to_s
    @@allRunLogger.setPostPrefix(runName)

    if @@useLocalHostAsServer
      throwUpServer
    end

    #if @@useLocalHostAsListener
    #throwUpListener
    #end

    # now do multiple or single
    if style == :multiple
      Driver.doMultiple runName, multiples_variant
    else
      assert style == :single
      Driver.doSingle runName
    end

    exit # don't display the help screen--why necessary tho?

    # ltodo cleaner error message when vary_parameter called with bad run name

  end   # ltodo include analogger

  def Driver.doSingle runName
    Driver.purgeListedPeersIfDeadOrBusy @@numClientsToSpawn
    Driver.newFileName # does less ltodo use (?)
    totalSeconds = @@numClientsToSpawn * @@spaceBetweenNew
    directoryName = Listener.getOutputDirectoryName @@blockSize, @@spaceBetweenNew, totalSeconds, @@dT, @@dR, @@dW, @@linger, runName, @@serverBpS
    if File.directory?(directoryName)
      raise "\n\n\n\n directory for logs #{directoryName} already exists, possible double run! ack!"
    end
    Driver.doSingleRunWithCurrentSettingsAndGraph(runName) # just the name to make the output pics jive with graphs...hmm...odd
  end



  # rubydoctest: if you have not a file named run_in_progress_XXXX then it should run
  # >> a = Thread.new { system("ruby driver.rb --just_display_what_would_have_run_for_multiples --do_small_variant_test") }
  # >> sleep 5
  # >> a.alive?
  # => false
  # rubydoctest: if you have a file run_in_progress_XXX then it should wait, then run, even for just displaying the runs
  # >> FileUtils.touch 'run_in_progress_test_run'
  # >> a = Thread.new { system("ruby driver.rb --just_display_what_would_have_run_for_multiples --do_small_variant_test") }
  # >> sleep 3
  # >> a.alive?
  # => true
  # >> File.delete('run_in_progress_test_run')

  def Driver.doMultiple runName, runStyle
    @@allRunLogger.log "doing run #{ARGV.inspect}"
    settingsToTryArray = nil
    setupOnceString = ''
    unitsX = "Peers per second";  # default
    foreignServerPort = "7778"
    codeToExecuteAfterEachMajorLoopAndAtBeginning = nil
    codeToExecuteBeforeEachRun = nil
    # running multiples leaves all the other constants the same, basically, as they were set.

    assert @@multiples_variant_possibilities.index(runStyle), 'must have a multiples variant in ' + @@multiples_variant_possibilities.inspect + "you passed us " + runStyle

    if runStyle.contains? "peersPerSecond" or runStyle.contains?('multipleFiles')
      whatToAddTo = "peersPerSecond"
      unitsX = "Peers per Second"
      settingsToTryArray = [1,2,3,6,10,15,20,25] # HERE IT IS one other option: [1,2,5]
      total_seconds = 100 # can be 10 for tests
      codeToExecuteAfterEachMajorLoopAndAtBeginning = proc {
        @@spaceBetweenNew = 1.0/peersPerSecond
        @@numClientsToSpawn = total_seconds*peersPerSecond
      }
    end

    if runStyle == "peersPerSecondCS"
      setupOnceString << "$PRETEND_CLIENT_SERVER_ONLY = true;"
    elsif runStyle == "peersPerSecondP2P"
      # pass
    end

    if runStyle.contains? 'multipleFiles'
      @@dw=3
      @@dt=3
      @@total_files_to_use = 10
    end

    if runStyle == 'multipleFilesCS'
      @@dt = 100000
      @@dw = 100000
      @@linger = 0
    end

    if runStyle == "dT"
      whatToAddTo = "@@dT"; settingsToTryArray = [0.0, 0.1, 0.25, 0.5, 0.75, 1, 1.5, 2, 3, 4, 5, 10];  unitsX = "T (seconds)"
    end

    if runStyle == 'dR'
      #R from 50Kbps to 1 MBps
      setupOnceString += "@@dT = 10;"
      whatToAddTo = "@@dR";
      settingsToTryArray = [5.kbps, 10.kbps, 20.kbps, 40.kbps, 80.kbps, 160.kbps, 320.kbps, 640.kbps, 1000.kbps];
      unitsX = "R (B/S)"
    end

    if runStyle == 'dW'
      # and vary W from 1s
      #  to 10s
      setupOnceString += "@@dT = 10;"
      whatToAddTo = "@@dW"; settingsToTryArray = [0.10, 0.25, 0.5] + (1..10).map{|n| n}
      unitsX = 'dW (seconds)'
    end

    if runStyle == 'linger'
      whatToAddTo = "@@linger"
      settingsToTryArray = [0, 1,2,4,8,16,40,80,160]
      unitsX = "Linger Time (s)"
    end

    if runStyle == "smallTest"
      setupOnceString += "@@numClientsToSpawn = 3;"
      whatToAddTo = "@@dT"; settingsToTryArray = [1, 3];  unitsX = "T (seconds) -- smalltest";
      @@howManySubRepetitions = 2
      @@linger = 0
    end

    if runStyle == "teenyTest"
      setupOnceString += "@@numClientsToSpawn = 1;"
      whatToAddTo = "@@dT"; settingsToTryArray = [1];  unitsX = "T (seconds) -- smalltest";
      @@howManySubRepetitions = 1
      @@linger = 0
    end


    if runStyle == 'blockSize'
      whatToAddTo = '@@blockSize'
      settingsToTryArray = [16.kb, 32.kb, 64.kb, 100.kb]
      unitsX = 'Block size'
    end

    if runStyle == 'serverBpS'
      whatToAddTo = '@@serverBpS'
      settingsToTryArray = [32.kb, 64.kb, 128.kb, 256.kb, 512.kb, 1000.kb, 2000.kb]
      unitsX = 'Server Speed (B/s)'
      codeToExecuteAfterEachMajorLoopAndAtBeginning = proc {
        print system("./set_remote_server_speed_redirected.sh #{@@serverBpS}")
      }
    end

    if runStyle == 'bitTorrent' || runStyle == 'largeFile'
      whatToAddTo = '@@url_use_bittorrent'
      settingsToTryArray = [false, true] # YANC vs. BT :)
      #    settingsToTryArray = [true] # BT only
      @@linger = 0
      @@numClientsToSpawn = 100
      if @@test
        print "doing test Bt//largefile -- 1 client only"
        @@numClientsToSpawn = 1
      end
      unitsX = 'Using BitTorrent'
      @@fileSize = 30.mb
      @@blockSize = 256.kb

      codeToExecuteBeforeEachRun = proc {
        system('ssh byu_p2p@planetlab1.flux.utah.edu "~/kill_planetlab1.byu.edu_python.sh"') # start over the tracker, etc--because otherwise the seed bugs and doesn't give us anything!
      }
    end

    if runStyle == 'largeFile'
      @@url_use_bittorrent = false
      unitsX = 'Simultaneous peers from whom to download'
      settingsToTryArray = [1,2,4,8,16,26,50]
      whatToAddTo = '@@peerTokens'
      #	settingsToTryArray = [false] # YANC only
      codeToExecuteBeforeEachRun = proc {
        system('ssh byu_p2p@planetlab1.flux.utah.edu "ssh byu_p2p@planetlab1.byu.edu \" /home/byu_p2p/installed_apache_2/bin/apachectl -k restart\""')
      }
    end

    raise 'must specify what is varying' unless whatToAddTo

    if !settingsToTryArray and not defined? firstValue # then use some default values -- not sure if these are ever even used
      firstValue = 0.01; operator = "*="; operandEachMajorLoop = 2; # the normal 'ramp up' way
      howManyStepsOfTheMajorVariable = 2 # constant
    else
      howManyStepsOfTheMajorVariable = settingsToTryArray.length
      operator = '='
      firstValue = settingsToTryArray.shift
      operandEachMajorLoop = 'fixed_setting' # for output
    end
    Driver.initializeVarsAndListeners nil, setupOnceString

    # ltodo a backoff on the origin key by querying +rand(1000000) +rand(10000) etc. and setting oneself to those, as well [ok maybe not a great idea...hmm..] or geographic queries (not random) [a la that one thing Leopard]
    Driver.purgeListedPeersIfDeadOrBusy 1000, false if @@actuallyPerformMultipleRuns # all, for helping us try to test more accurely (i.e. don't only use the faster hosts) # ltodo when you purge randomize first ltodo this is ugly!!

    howVaried = []
    runNamesForEachHowVaried = []
    run_objects_for_how_each_varied_to_avoid_having_to_recompute = []
    eval("#{whatToAddTo} = #{firstValue}")
    codeToExecuteAfterEachMajorLoopAndAtBeginning.call if codeToExecuteAfterEachMajorLoopAndAtBeginning
    @@allRunLogger.log "instantiated #{whatToAddTo} at " + eval("#{whatToAddTo}").to_s

    whatToAddToFilenameSanitized = whatToAddTo.to_s.gsub('@', '')
    varyParameterOutputName = "vr_#{runName}_#{whatToAddToFilenameSanitized}_fromStart_" + eval("#{whatToAddTo}").to_s + "by_#{operandEachMajorLoop}AndMajorTimes_#{howManyStepsOfTheMajorVariable - 1}_times_#{@@spaceBetweenNew}s_" +
    "_#{@@linger}s_#{@@fileSize}B_#{@@serverBpS}BPS_#{@@dR}s_#{@@dT}s_#{@@dW}s_#{@@blockSize}B"

    @@allRunLogger.log "Starting overall multi-run, multi-parameter driver run varying #{varyParameterOutputName} #{howManyStepsOfTheMajorVariable} steps"
    massive_grapher =  VaryParameter.new(MultipleRunsSameSettingGrapher.pictureDirectory + '/vary_parameter/' + varyParameterOutputName, unitsX) if @@actuallyPerformMultipleRuns and $shouldDoVaryParameterGraphs
    Driver.measure_time("full total complete all run") do
      1.upto(howManyStepsOfTheMajorVariable) { |major_variable_step|

        runNamesForThisSetting = []
        settingForThisMajorStep = eval("#{whatToAddTo}").to_s
        @@allRunLogger.log "NEXTTTTTTTT major step of variable!doing #{whatToAddTo} currently set at " + settingForThisMajorStep + "\n\n\n\n\n"
        1.upto(@@howManySubRepetitions) { |n|
          # attempt at avoiding concurrency probs. Not sure if this belongs here or in doSingleRunWithCurrent
          my_run_marker = ENV['HOME'] + "/bittorrent_#{@@url_use_bittorrent}_run_in_progress_" + 'pid:' + Process.pid.to_s + '_' + Socket.gethostname
          all_contestants = ENV['HOME'] + "/bittorrent_#{@@url_use_bittorrent}_run_in_progress_*"
          while (all = Dir.glob(all_contestants)) != [my_run_marker]
            File.delete my_run_marker if File.exist? my_run_marker
            if Dir.glob(all_contestants) == []
              FileUtils.touch my_run_marker
            else
              print "waiting for other run to end #{all}"
              sleep 1
            end
          end
          begin
            Driver.newFileName

            run_name_single_run = runName + "_#{whatToAddToFilenameSanitized}_at" + settingForThisMajorStep + "_run#{n}_of_#{@@howManySubRepetitions}_major_#{major_variable_step}_of_#{howManyStepsOfTheMajorVariable}" # sanitize out the @'s
            totalTime = @@numClientsToSpawn*@@spaceBetweenNew

            @@allRunLogger.log "driving NEXT (possibly first) single run! name:#{run_name_single_run}  block size: #{@@blockSize}, file size: #{@@fileSize}, clients: #{@@numClientsToSpawn} (for #{totalTime}s), dT:#{@@dT}, dR:#{@@dR}, dW:#{@@dW}, linger: #{@@linger} server estimated speed: #{@@serverBpS} space between: #{@@spaceBetweenNew} \n\n"

            codeToExecuteBeforeEachRun.call if codeToExecuteBeforeEachRun

            Driver.measure_time("perform run #{run_name_single_run}") {
              Driver.doSingleRunWithCurrentSettings(:runName => run_name_single_run, :totalToPotentiallyIgnoreLastPeers => 6) if @@actuallyPerformMultipleRuns
            }
          ensure
            File.delete my_run_marker
          end
          # now pick up the pieces :)
          restartThread = Thread.new { # small optimization
            Driver.sendAllListeners("restart") { |peer, port, answer| # ltodo just use purged list
              print "affirmative restart from #{peer} #{port} \n\t=> #{answer}"
            }
          } if @@actuallyPerformMultipleRuns && !@@useLocalHostAsListener && !runStyle.in?( ['smallTest', 'teenyTest', 'multipleFiles'])

          runNamesForThisSetting << run_name_single_run
          restartThread.wait_till_dead(60) if restartThread and !runStyle.in? ['smallTest', 'teenyTest', 'multipleFiles'] # the only reason wait_till_dead is that sometimes it would hang--suspected Ruby bug [?]
        } # ltodo don't use @@ as much here...

        current_setting_of_the_variance_variable = eval("#{whatToAddTo}").to_f
        howVaried << current_setting_of_the_variance_variable
        runNamesForEachHowVaried << runNamesForThisSetting # needed?

        @@allRunLogger.log "about to make single graphs single multiple (1x3) [#{runNamesForThisSetting}]"

        if @@actuallyPerformMultipleRuns
          [1].forky  {
            all_runs_this_setting = []
            for name in runNamesForThisSetting do
              Driver.measure_time("parsing and statting single graph") {
                all_runs_this_setting << Driver.graphAndStatSingleRun(name, "vary_parameter_singles/" + name) if $shouldDoGraphsSingle and @@actuallyPerformMultipleRuns
              }
            end
            # now do these multiple (single major loop) graphs
            combined_runs = nil # heh
            Driver.measure_time('multiple graph creation -- I think should be about instant') {
              combined_runs = MultipleRunsSameSettingGrapher.new(runNamesForThisSetting, "vary_parameter_singles/st_" + runName + whatToAddToFilenameSanitized + "_at_" + settingForThisMajorStep + "_severalTogether", all_runs_this_setting)
            }
            [1].forky { # could truly fork here--if RAM would allow it [check]
              Driver.measure_time('sub multiple graph like a row worth, their graphs') {
                combined_runs.doAll();
              }
            }
            # and add to the overall specs:
            Driver.measure_time('massive graph add one') {
              #            dbg # add
              massive_grapher.add_run_object_and_its_setting(combined_runs, current_setting_of_the_variance_variable, runNamesForThisSetting) # so this within a fork -- our theoretical saver
            }
          }
        end

        # calculate next step
        if settingsToTryArray
          operandEachMajorLoop = settingsToTryArray.shift # next value
          assert operator == '='
        end
        eval("#{whatToAddTo} #{operator} #{operandEachMajorLoop}") if operandEachMajorLoop # don't perform this if it's the last time on an array setting, as it will attempt to assign something nil...hmm...
        codeToExecuteAfterEachMajorLoopAndAtBeginning.call if codeToExecuteAfterEachMajorLoopAndAtBeginning
      }

      # all done!
      puts 'ran:' + howVaried.inspect  + "\n\n\n\n"

      if $shouldDoVaryParameterGraphs
        # these will not run as well if set for a single setting...therefore
        if runNamesForEachHowVaried.length == 1 # handle the case of not actually varying the variable :)
          print "PRETENDING TO HAVE DONE MORE THAN ONE SETTING OF THE VARIABLE, TO ALLOW For some graphical numbers THIS IS PROBABLY BROKEN!!!"
          runNamesForEachHowVaried = [runNamesForEachHowVaried[0], runNamesForEachHowVaried[0] + '_fake']
          run_objects_for_how_each_varied_to_avoid_having_to_recompute *= 2
        end
        # note: should get printed out twice--one with the 'about to start' then one after done :)
        varyDescriptionString = "vary parameter graphs of VaryParameter.varyParameterAndRsync('vary_parameter/#{varyParameterOutputName}', '#{unitsX}'," + howVaried.inspect + "," + runNamesForEachHowVaried.inspect + ") " + "\n --- with runs generated of "+ runNamesForEachHowVaried.join(',')

        Driver.measure_time(varyDescriptionString) {
          # actually do
          massive_grapher.doGraphs if @@actuallyPerformMultipleRuns # this one pre-created and fed data one at a time so that we can garbage collect old runs
        }
      end
    end
    exit # ltodo figure out why this line is necessary, as not having it causes the driver to spit out its instructions twice
  end

  # vltodo if you do it with 'flood me!' with 10B file, even off normal host, takes 0.2 s total -- optimize :)
  # ltodo double check no extraneous threads
  # note in real life use only IP's :) [compare with DNS, too]

  def initialize logger
    @logger = logger
    # ltodo initialization string :)
    @timeStarted = Time.new
    @log_prefix = 'driver'
  end
  include Logs

  # lodo have 'dual keys' and dual key queries, to get the very fastest put/gets
  class Firer < EventMachine::Connection
    def Firer.go parent, fullUrl, blockSize, fileSize, spaceBetweenNew, totalSecondsToContinueGeneratingNewClients, dT, dR, dW, linger, runName, serverBpS, peer_tokens, peer_name, startTime, logger
      startTimeHere = Time.now # in case there's a repeat.
      begin
        peerToFire = parent.peers.shift
        parent.peers << peerToFire # put it on the tail for later :)
        host = peerToFire[0]
        port = peerToFire[1]
        logger.log "attempting to fire to #{peer_name} to #{host}:#{port} (out of candidates #{parent.peers.length}) [and I will keep going forever if necessary]\n" # ltodo cull those that are dead so we avoid this...at the beginning
        EM::connect_from_other_thread(host, port, Firer) { |conn|
          success_answer_proc = proc {|successful|
            if successful == :success
              parent.sumReallyStarted += 1
              parent.peersUsed[host] = port
              parent.log "success--fired #{peer_name} to #{host}:#{port} -- total listenered used count is now #{parent.peersUsed.length}"
            else
              EM::Timer.new(0.1, proc { Firer.go parent, fullUrl, blockSize, fileSize, spaceBetweenNew, totalSecondsToContinueGeneratingNewClients, dT, dR, dW, linger, runName, serverBpS, peer_tokens, peer_name, startTime + (Time.now - startTimeHere), logger } ) # try to resend
            end
            conn.instance_variable_set :@got_reply, true
          }

          connection_completed_proc = proc {
            secondsExtra = Time.now - startTimeHere
            conn.send_data [fullUrl, blockSize, fileSize, spaceBetweenNew, totalSecondsToContinueGeneratingNewClients, dT, dR,
              dW, linger, runName, serverBpS, peer_tokens, peer_name, (startTime + secondsExtra).to_f.to_s, $p2pSkipCS,
            $doNotInterruptOriginThreadButYesP2P, $PRETEND_CLIENT_SERVER_ONLY, $useOriginRevertOptimization, $useOriginBackOffOrNumberConcurrent, $getAllAtBeginning, $USE_MANY_PEERS_NO_SINGLE_THREAD].join(",")
            EM::Timer.new(30) { unless conn.instance_variable_get(:@got_reply); logger.debug "closing for having taken too long to reply";conn.close_connection; end }
          }

          conn.init success_answer_proc, connection_completed_proc

        }
      rescue RuntimeError
        logger.error "retrying!"
      end
    end

    def init success_proc, conn_completed_proc
      @success_failure_block = success_proc
      @connection_completed_block = conn_completed_proc
    end

    def connection_completed
      @connection_completed_block.call
    end

    def receive_data message
      if message =~/success/
        @success = :success
      else
        print "failure with receipt #{message}" # ltodo log
      end

    end

    def unbind
      @success_failure_block.call(@success || :failure)
    end
  end

  def Driver.each_listener_as_thread
    assert block_given?
    allThreads = []
    for peer, port in @@peers
      allThreads << Thread.new(peer, port) { | peer2, port2|
        print "started thread #{Thread.current} #{peer2} #{port2}\n"
        yield peer2, port2
      }
    end
    print "mass joining\n"
    begin
      allThreads.each{|t| print "joining on #{t}\n"; t.join}
    rescue Interrupt
      print "nice ctrl-c!\n"
    end
  end

  def Driver.each_peer_host
    for peer, port in @@peers
      yield(peer, port)
    end
  end

  def Driver.peer_count
    @@peers.length
  end

  def Driver.runBlocksOnListeners(conn_complete_block, unbind_block = nil, receive_data_block = nil)	 # hanging here may mean you forgot to close the connection
    sum_answered = 0
    Driver.each_peer_host {|peer, port|
      begin
        EM::connect_from_other_thread( peer, port, SingleConnectionCompleted) {|conn|
          conn.connection_completed_block = conn_complete_block if conn_complete_block
          conn.unbind_block = proc{|conn2| sum_answered += 1; unbind_block.call(conn2) if unbind_block}
          conn.receive_data_block = receive_data_block if receive_data_block
        }
      rescue RuntimeError
        sum_answered += 1
      end
    }
    begin
      sleep 0.1 while sum_answered < Driver.peer_count
    rescue Interrupt
      print "continuing..."
    end
  end

  named_args_for :'self.runBlocksOnListeners'

  def Driver.sendAllListeners(thisMessage, failureBlock = nil, &blocky) # blocky wants .call peer, port, answer
    logMutex = Mutex.new
    numberAnswered = 0
    Driver.runBlocksOnListeners :conn_complete_block => proc {|conn| conn.send_data thisMessage; }, :receive_data_block => proc {|conn, data| blocky.call(conn.get_tcp_connection_info_hash[:peer_host], conn.get_tcp_connection_info_hash[:peer_port], data); conn.close_connection; numberAnswered += 1}
    print "Numbered answered something [0 might be ok]: #{numberAnswered} out of #{@@peers.length}"
  end
  # ltodo have a few 'volunteer' to serve for longer, or something...must...preserve...livenes....

  # ltodo host back off
  # ltodo run single_client win32 vs. ilab1 -- ummm...why so much slower?

  def Driver.singleClientLocalAgainstForeign
    $PRETEND_CLIENT_SERVER_ONLY = false
    @@useLocalHostAsListener = true

    #@@fileUrl = "http://download.oracle.com/berkeley-db/db-4.5.20.tar.gz"
    #@@fileUrl = "http://wilkboardonline.com/1000K.file"
    #$shouldDoGraphsSingle = false
    #$shouldDoVaryParameterGraphs = false
    throwUpListener
    Driver.initializeVarsAndListeners
    Driver.singleClientGoWithNewFileName
  end

  def Driver.singleClientLocalAgainstLocal
    #EM::fireSelfUp
    @@useLocalHostAsServer = true # so prefab server will work
    Driver.initializeVarsAndListeners # set the @@fileSize
    recalculateCurrentGlobalUrl @@fileSize # tlodo not use
    server = BlockManager.startPrefabServer
    client = Driver.singleClientLocal
  end

  # ltodo download that berkeley db guy! fix bug!
  def Driver.singleClientLocal
    #$USE_MANY_PEERS_NO_SINGLE_THREAD = true
    $serverBpS = (@@fileSize/4).ceil
    $PRETEND_CLIENT_SERVER_ONLY = false
    @@useLocalHostAsListener = true

    Driver.initializeVarsAndListeners
    @@blockSize = @@fileSize/5
    @@fakeStartWaitAsSeconds = nil
    @@fakeStartAddedLinger = nil
    @@dT = 1.0
    @@dW = 1.0
    @@dR = 1.mb # try to make it break after a little CS only :)
    @@linger = 1
    Driver.singleClientGoWithNewFileName
  end

  def Driver.singleClientGoWithNewFileName
    throwUpListener
    Driver.newFileName
    Driver.singleClientGo
  end

  def Driver.singleClientGo
    @@numClientsToSpawn = 1
    @@spaceBetweenNew = 1
    @@dR = 1e6
    doSingleRunWithCurrentSettingsAndGraph("single_run" + rand(10000).to_s)
  end

  def Driver.doSingleRunWithCurrentSettingsAndGraph(runName, totalToPotentiallyIgnoreLastPeers = 5)
    Driver.doSingleRunWithCurrentSettings(runName, totalToPotentiallyIgnoreLastPeers)
    if $shouldDoGraphsSingle # ltodo only do this once in code...
      Driver.graphAndStatSingleRun(runName)
    end

  end

  def Driver.rss_current
    if RUBY_PLATFORM =~ /darwin/
      `ps u | grep #{Process.pid} | grep -v grep`.strip
    elsif RUBY_PLATFORM =~ /mingw|mswin/
      0
    else
      # assume linux
      (File.read "/proc/#{Process.pid}/statm").strip
    end
  end

  def Driver.measure_time message = nil
    @@allRunLogger.log "begin timing #{message} ram before running it: #{rss_current}"
    time = Benchmark.measure { yield }
    msg = " #{message} took #{time.inspect} #{time.real/60.0/60}h RAM usage now: #{rss_current} #{Time.now}"
    @@allRunLogger.log msg
    msg
  end

  def Driver.doSingleRunWithCurrentSettings(runName, totalToPotentiallyIgnoreLastPeers) # ltodo stinky
    startAllPeersAndWaitForCompletion @@blockSize, @@fileSize, @@spaceBetweenNew, @@numClientsToSpawn, @@dT, @@dR, @@dW, @@linger, runName, @@serverBpS, @@allRunLogger, totalToPotentiallyIgnoreLastPeers, @@peerTokens
  end

  named_args_for :'self.doSingleRunWithCurrentSettings'

  def Driver.graphAndStatSingleRun(runName, outputName = runName)
    @@allRunLogger.debug "graphing single #{runName} => #{outputName}"
    a = MultipleRunsSameSettingGrapher.new([runName], outputName)
    [1].forky {
      # deemed wasteful a.doAll();
      measure_time("single stats for #{runName}") {VaryParameter.doStatsSingleRun(runName, [a], a.dirName) }
    }
    a
  end

  def Driver.poissonInteger(mean)
    #  init
    l = Math.exp(-mean)
    k = 0
    p = 1
    while p >= l
      k += 1
      u = rand
      p = p *u
    end
    return k -1
  end


  def Driver.moveNumberWithFirstSigFigInOnesToMathSigFig(numberWantingToMatch, numberToMatch)
    significantFirstLocation = Driver.significantFirstLocationIfUsedAsTensExponent numberToMatch
    numberWantingToMatch *= 10**significantFirstLocation
  end

  def Driver.significantFirstLocationIfUsedAsTensExponent(number)
    significantFirstLocation = Math.log10(number).to_i
    significantFirstLocation -= 1 if number < 1 # account for less than one with that weird negative exponent...hmm...
    significantFirstLocation
  end

  def Driver.stripToFirstSigInOnesLocation(number)
    significantFirstLocation = Driver.significantFirstLocationIfUsedAsTensExponent number
    return number.to_f/(10**significantFirstLocation)
  end

  def Driver.nextArrival(mean)
    # so if we get a mean of 1.5, let's get a poisson of 150 and divide by 100
    # I want means of like [it's 5] => [2,6,3,5,5,4,7,8,5] or...within the same sig fig.
    # or 150 => 15 => [14, 13, 16, 17] => [140, 130, 160, 170]
    # or 100 => 10 => 9, 11, 12, 13 => 90, 110, 120, 130
    reasonableCenter = stripToFirstSigInOnesLocation(mean)*10 # center around 10 -- seems reasonable
    bigPoisson = Driver.poissonInteger(reasonableCenter)
    normalizedPoisson = bigPoisson/10.0  # ~ (around 1.5) 1.5, 1.4, 1.7
    normalizedPoissonWithSameSigFigs = Driver.moveNumberWithFirstSigFigInOnesToMathSigFig(normalizedPoisson, mean)
    normalizedPoissonWithSameSigFigs
  end
  attr_reader :peersUsed, :peers
  attr_accessor :sumReallyStarted
  def doAllPeersWithDelta(fullUrl, blockSize, fileSize, spaceBetweenNew, totalNumberClients, dT, dR, dW, linger, runName, serverBpS, peer_tokens, totalToPotentiallyIgnoreLastPeers = 5)

    peer_name = 0
    @uniqueRunName = runName
    threads = []
    @peersUsed = {}

    totalSecondsToContinueGeneratingNewClients = totalNumberClients * spaceBetweenNew
    raise "cant do a run with totalNumberClients #{totalNumberClients} spaceBetweenNew #{spaceBetweenNew}" if totalSecondsToContinueGeneratingNewClients == 0
    @logger.debug "go with delta starting run name...#{@uniqueRunName} delta #{spaceBetweenNew} total clients #{totalNumberClients}"
    # ltodo log the 'time' better to 'subtract' the processing time or something...like...that...
    @sumReallyStarted = 0
    @peers = @@peersPurged
    total_clients_actually_spawned_before_control_c = 0
    EM::fireSelfUp
    if @@fakeStartWaitAsSeconds
      @logger.error "FAKE STARTING IT!"
      if @@fakeStartAddedLinger
        @logger.error "WITH FAKE ADDED LINGER"
      end
      Firer.go(self, fullUrl, blockSize, fileSize, spaceBetweenNew, totalSecondsToContinueGeneratingNewClients, dT, dR, dW, @@fakeStartAddedLinger, runName, serverBpS, peer_tokens, peer_name, Time.new - @timeStarted, @logger)
      @logger.debug "sleeping #{@@fakeStartWaitAsSeconds}s fake start"
      sleep @@fakeStartWaitAsSeconds
    end

    begin
      totalNumberClients.to_i.times do # while (Time.new - @timeStarted) < totalSecondsToContinueGeneratingNewClients
        total_clients_actually_spawned_before_control_c += 1
        Firer.go(self, fullUrl, blockSize, fileSize, spaceBetweenNew, totalSecondsToContinueGeneratingNewClients, dT, dR, dW, linger, runName, serverBpS, peer_tokens, peer_name, Time.new - @timeStarted, @logger)
        peer_name += 1
        sleepTime = Driver.nextArrival(spaceBetweenNew)
        sleep sleepTime
      end
    rescue Interrupt
      print "come on you'll mess up the number!\n"
    end
    @logger.debug "waiting for firing to finish!"
    sleep 0.1 while @sumReallyStarted < total_clients_actually_spawned_before_control_c
    @logger.debug "Driver done firing threads, now will monitor listeners+collect!"
    start_collect_time = Time.now
    allPeersLeft = @peersUsed.dup
    puts @peersUsed.inspect
    begin
      remove_mutex = Mutex.new
      start_time = Time.now
      allThreads = startThreadsThenJoin(@peersUsed, false) { |ip, port|
        doneWithPeer = false
        retries_left = 30
        while not doneWithPeer # let it get queried a few times till it answers yes...
          begin
            @logger.debug "asking #{ip}:#{port} if done (after #{Time.now - start_time}s)"
            sockOut = TCPSocket.new(ip, port)
            sockOut.write("doneWithRun?")
            sockOut.flush
            answer = nil
            Timeout::timeout(60) {
              answer = sockOut.recv(10000) # ltodo guard it this might fail in error if they are slammed! do it twice
            }
            sockOut.close
            outString =  "#{allPeersLeft.length} total proxies left (running or rsyncing)"
            if answer == "yes"
              @logger.debug "#{ip}:#{port} is finished yes!!!!!!!!!!!!!!!!!! " + outString
              doneWithPeer = true
            else
              doneWithPeer = false
              sleepTime = 4 # HERE IS WHERE TO CHANGE HOW LONG TO WAIT BETWEEN PINGS FOR ACTIVE LISTENERS
              @logger.debug "at #{Time.now - start_collect_time}s waiting #{sleepTime}s for #{ip}:#{port} to finish up [said #{answer}]..." + outString
              sleep sleepTime
            end
          rescue Exception => detail
            retries_left -= 1
            retries_left += 1 if detail.class == Timeout::Error and @@url_use_bittorrent # bittorrent currently can take as long as it wants
            @logger.error "asked listener if done--#{ip}:#{port} erred! #{detail}"
            if retries_left > 0
              @logger.error "retrying with #{retries_left} left"
              doneWithPeer = false
              sleep 1
            else
              @logger.error "NOT retrying---giving up...sniff..."
              doneWithPeer = true
            end
          end
        end
        remove_mutex.synchronize {
          allPeersLeft.delete(ip)
          allPeersLeft[ip + 'rsyncing'] = true
        }
        # I think we should always want to rsync it...
        Driver.rsyncThese [[ip,port]],  @logger, Listener.getOutputFileNameAfterIP(blockSize, spaceBetweenNew, totalSecondsToContinueGeneratingNewClients, dT, dR, dW, linger, runName, serverBpS) + "/" # a single rsync
        remove_mutex.synchronize {
          allPeersLeft.delete(ip + 'rsyncing')
        }
      }

      # now we have allThreads
      maximumTimeForLastFew = 20.minutes # they cannot need more than this!
      while allPeersLeft.length > totalToPotentiallyIgnoreLastPeers
        print "#{allPeersLeft.length} left > #{totalToPotentiallyIgnoreLastPeers} desired, ex #{allPeersLeft.to_a[0]} "
        sleep 1
      end
      @logger.debug "#{allPeersLeft.length} left! --starting #{maximumTimeForLastFew}s countdown\n\n\n"
      countDownStart = Time.new
      while (Time.new - countDownStart) < maximumTimeForLastFew and allPeersLeft.length > 0
        print "#{maximumTimeForLastFew - (Time.new - countDownStart)} l(#{allPeersLeft.inspect}) "; STDOUT.flush;
        3.times do
          sleep 1
          print "\n"
          break if allPeersLeft.length == 1
        end
      end
    rescue Interrupt
      print "come on is it that painful? impatient\n"
      pp "all left that haven't said they're done: ", allPeersLeft
    end

    if !allPeersLeft.empty?
      pp "doing rsync on these weird left-over ones", allPeersLeft
      Driver.rsyncThese allPeersLeft.sort, @logger, Listener.getOutputFileNameAfterIP(blockSize, spaceBetweenNew, totalSecondsToContinueGeneratingNewClients, dT, dR, dW, linger, runName, serverBpS) + "/"
    end
    @logger.debug "DONE driving and collecting for run number #{@uniqueRunName} "
  end

  def Driver.rsyncAll
    Driver.rsyncThese @@peers, Logger.new("rsync_all_out", 0), "", 10
  end

  def Driver.rsyncSingleRunToHere runName
    Driver.initializeVarsAndListeners
    totalSecondsToContinueGeneratingNewClients = @@spaceBetweenNew * @@numClientsToSpawn
    Driver.rsyncThese @@peers, Logger.new("../logs/rsync_singleruntohere_out", 0), Listener.getOutputFileNameAfterIP(@@blockSize, @@spaceBetweenNew, totalSecondsToContinueGeneratingNewClients, @@dT, @@dR, @@dW, @@linger, runName, @@serverBpS) + "/"

  end

  def Driver.rsyncThese thesePairsArray, logger, pathWithEndingSlash = "", threads = 20
    print "doing #{threads} simultaneous rsync threads" if thesePairsArray.length > 1
    allThreads = []
    grabMutex = Mutex.new

    threads.times do
      allThreads << Thread.new {
        # a thread pool!
        while thesePairsArray.length > 0
          nextGuy = nil
          grabMutex.synchronize {
            nextGuy = thesePairsArray.pop
          }
          if nextGuy
            ip, port = nextGuy[0], nextGuy[1]
            assert ip && port
            print "ip is ", ip.inspect, "\nn\n\n\n"
            next if ip =~ /ilab/
            next if ip == '127.0.0.1'
            next if ip == 'localhost'
            next if ip == '192.168.21.102' # ilab2 LTODO this shouldn't be necessary
            ip2 = Socket.get_ip(ip)
            logger.error 'blank host ip?' if ip2.blank?
            next if ip2 == Socket.get_host_ip
          else # probably empty
            next
          end

          logger.debug "collecting from #{ip}";
          begin
            retry_count = 5
            Dir.mkPath "../logs/#{ip}" unless File.directory? "../logs/#{ip}"
            command = "rsync --timeout=60 -rv byu_p2p@#{ip}:/home/byu_p2p/p2pwebclient/logs/#{ip2}/#{pathWithEndingSlash.escape}* ../logs/#{ip}/#{pathWithEndingSlash.escape}"# ltodo pl1_1_run_dClient_0.25_dTotal_1.25_dw_5.0_blockSize_100000_linger_3_dr_187500.0_dt_1_serverBpS_250000
            puts command
            success = false
            while !success and retry_count > 0
              success = system(command)
              print "#{retry_count} left for rsync #{ip}" unless success
              retry_count -= 1
            end
          rescue SocketError, Exception => detail
            logger.warn "unable to rsync from #{ip} -- #{detail}!!"
          end
        end
      }
    end
    logger.debug "joining on rsyncing threads"
    allThreads.joinOnAllThreadsInArrayDeletingWhenDead
  end

  class PurgedEnough < StandardError
  end
  # this is another example of a use of threadRace that just...needs either a signal OR all threads to terminate ltodo [i.e. terminating not good enough] or another counter...
  def Driver.purgeListedPeersIfDeadOrBusy totalNeeded = 1000, disregardIfBusy = true
    print "purging\n"
    @@peersPurged = []
    @@peersAlive = []
    # let's poll!
    number_done = 0
    @@peers.randomizedVersion.each do |peer, port|
      print "attempting #{peer}:#{port} -- asking if they're doneWithRun?\n"
      begin

        EM::connect( peer, port, SingleConnectionCompleted) {|conn|
          conn.connection_completed_block = proc {|conn| conn.send_data "doneWithRun?" }

          conn.receive_data_block = proc {|conn, data|
            if data == "yes"
              print "got an idle [ready] peer #{peer} #{port}"
              @@peersAlive << [peer, port]
            else
              print "got a busy peer: #{peer} #{port} #{data}"
            end
            conn.instance_variable_set :@got_one, true
            number_done += 1
            conn.close_connection
          }
          conn.unbind_block = proc { |conn|
            print "unbind"
            number_done += 1 unless  conn.instance_variable_get :@got_one
          }
        }
      rescue RuntimeError => e
        print "erred #{e}\n"
        number_done += 1
        # no server
      end
    end

    begin
      start_time = Time.now
      while (number_done < @@peers.length) and (Time.now - start_time < 40)
        print "waiting...got #{number_done} (#{@@peersAlive.length} successful) out of total possible #{@@peers.length}\n"
        sleep 1
      end
    rescue Interrupt
      print "CONTINUING WITH ONLY #{number_done} out of #{@@peers.length} total!\n"
    end
    print "done with first stage -- peers alive #{@@peersAlive.length}\n"
    # now check for version
    count_done = 0
    connection_completed_block = proc {|conn| conn.send_data "version"}
    receive_data_block = proc {|conn, received|
      versionReceived = received.split("\n")[0] # first line
      info = conn.get_tcp_connection_info_hash
      peer = info[:peer_host]
      port = info[:peer_port]
      if versionReceived != $version
        print "got different version #{versionReceived} != #{$version} from #{peer} #{port}"
      else
        print "got good peer #{peer} #{port} right version\n"
        @@peersPurged << [peer, port]
      end
    }
    unbind_block = proc {
      count_done += 1
    }
    Driver.runBlocksOnListeners connection_completed_block, unbind_block, receive_data_block
    begin
      sleep 0.1 while count_done < @@peersAlive.length
    rescue Interrupt
      print "now you wont have as many peers as you might have been able to for your peerpurged\n"
    end

    print "updating purged peers from total length (#{@@peers.length}) to purged length #{@@peersPurged.length} ...\n"
    assert @@peersPurged.length > 0, "need some peers in the purged to run it from!!"
    @@peersPurged = @@peersPurged.randomizedVersion
  end

  def Driver.startAllPeersAndWaitForCompletion blockSize, fileSize, spaceBetweenNew, numClients, dT, dR, dW, linger, runName, serverBpS, logger, totalToPotentiallyIgnoreLastPeers, peer_tokens
    serverPort = $localAndForeignServerPort #30001 + rand(10000) # ltodo better port, or don't use
    #   Driver.newfilename
    recalculateCurrentGlobalUrl fileSize # is this needed here? ltodo
    fullUrl = @@fileUrl
    logger.log "using server (pre running) on its port #{serverPort} and url #{fullUrl}\n"
    assert runName, "didn't pass me a run name for this run! weird!"
    totalSecondsToContinueGeneratingNewClients = spaceBetweenNew * numClients
    directoryName = Listener.getOutputDirectoryName blockSize, spaceBetweenNew, totalSecondsToContinueGeneratingNewClients, dT, dR, dW, linger, runName, serverBpS # tlodo take out totalSeconds...

    if !File.directory?(directoryName)
      print  "directory for logs #{directoryName} exists, possible double run! ack!"
    end
    Dir.mkPath(directoryName)

    # driver start
    logger.log "doing start all peers with #{[blockSize, spaceBetweenNew, totalSecondsToContinueGeneratingNewClients, dT, dR, dW, linger, runName, serverBpS, peer_tokens, fullUrl].join(',')}"
    Driver.new(logger).doAllPeersWithDelta(fullUrl, blockSize, fileSize, spaceBetweenNew, numClients, dT, dR, dW, linger, runName, serverBpS, peer_tokens, totalToPotentiallyIgnoreLastPeers)
    # vltodo graceful stop for those that start here
    print "done with single run", runName

  end
end

class FalseClass
  def to_i
    return 0
  end
  alias to_f to_i
end

class TrueClass
  def to_i
    return 1
  end
  alias to_f to_i
end

if File.expand_path($0) == File.expand_path(__FILE__) or debugMe('driver')
  EM::fireSelfUp
  Driver.runFromParsedArgs
  EventMachine::shutdownGracefully
end

###
#* the wait length before cutoff (5 s) should depend on the size of the
#file.  For a 100 KB file you may want to shrink that window to
#something smaller (1 second or even less).  For example, downloading a
#100 KB file on a 1 Mbps connection takes .8 seconds.  If I don't even
#get ANYTHING for .5 seconds I might be willing to give up at that
#point because I've already wasted more than half the download time
#doing nothing.


# ltodo make sure no more ELC3144 or what not in logs--hmm...that may add latency stick with IP numbers :)

# ltodo better make a function to 'vary parameters' easily [like 'vary dW from 0 to 20 by 5'] and do the runs automatically [just one after another--I hope change in time of day doesn't hurt us too bad].

#ltodo: when 'getting the same block from server' get different parts of the same block :) [more tight coordination] [optimize 200K from 5b/p/s muhaha]
#serving 200K files, 5 Bytes at a time, to 60 yields 8G I/O read? (put in as a ltodo).

# ltodo post
#why not to use many threads with Ruby and sockets:

#1) sometimes does not assign variables the wya you'd hope it would.
#it does not work well with sockets.  Since ruby thread 'context shifting' is significantly less frequent than the OS, your sockets might have incoming data waiting, that is only infrequently read.  Not a good idea.

#3) cross-threading when the system is hammered, of incoming socket data.  This is weird.  But it happens.


# ltodo tell Ruby they need a faster file.eof?
# ltodo force them all into p2p--you'll notice that none have the chance to download it immediately, then you're sunk! Optimize :)
