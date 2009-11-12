
# welcome...                        
#
$version = "$Rev: 1515 $"

require 'pp'
require 'socket'
require 'base64'

Dir.glob(File.dirname(__FILE__) + '/lib/gems_here/*').each{|d| $:.unshift "#{d}/lib" }
# we can load gems now.
# phew!
require 'sane'
$: << __DIR__
$: << __DIR__ + "lib"
require_rel 'unique_require' if RUBY_VERSION < '1.9'

#require 'facets/times' 
require 'arguments'
require 'andand.rb'

require 'digest/sha1'

$: << File.dirname(__FILE__) + '/lib/graphing/personal-gruff-0.2.8/lib' # gruff, for later

require_rel 'lib/ruby_useful_here.rb'

# EM
ruby_version = (RUBY_VERSION + '.' + RUBY_PLATFORM)
$: << __DIR__ + 'ext/em/' + ruby_version # em libs
ENV['INLINEDIR'] = 'ext/' + ruby_version # ext/xxx/.ruby_inline dirs

require 'eventmachine'
require_rel 'lib/event_machine_addons.rb'

EM::set_max_timers 10000

# ltodo: wonder if there's a speedup if, while during download of a very fast file, you belay the opendht registration till the end :) like a flood when you're done, only
require_rel 'lib/opendht/local_drive_dht.rb'

#require 'resolv-replace' # doesn't help EM! LTODO!

# ltodo: mention asynchronous additions to HTTP would be nice [though you could fake it currently with a request that just didn't return...forever--that would be good enough--or one that returns every one minute or something...eh...never would work]
# ltodo: but the asynchronous connections through the openDHT, that could help!
# ltodo something to get rid of waste--interlacing things using HTTP, something, anything
# oh wait--we don't really CARE about waste for small files, though.  Since we're in last block mode waste away :)
# ltodo 
# ltodo  recover from restart via file (ha ha)
# ltodo signed hashes everywhere
# ltodo se requerem mais que temos, esperar e mandar
# ltodo reuse connections (2 lados)
# ltodo HEAD requests after time (?)
# ltodo ability to say "I have this range but have quit, so it will never change"
# ltodo async (before) requests--useful?  allowed? If allowed.
# ltodo inter block interleaving stuffs
# ltodo share peer info (pass a linger header)
# ltodo optimize the range string?
# ltodo request with date wanted
# ltodo save as one large file
# ltodo switch blocks => greedy get, see if it helps (get ranges, try and get everything)
# ltodo see if one connection/peer (or x) better
# ltodo 
# ltodo url_has_all (yeah) and/or url_1
# ltodo overall--better opendht use
# ltodo request unended
# ltodo note: no security, no search, no privacy, no NAT
# ltodo unlike coral no bandwidth probs ever -- "protects the protectors"
# ltodo work for streams
# ltodo non-date yes url_1
# ltodo: if the file is small, use some type of hash based store system...to avoid those pesky disk accesses

#ltodo: the 'bundle them all up together' thing to speed transfer beyond normal HTTP :) [with a set order, of course, and optional as to which files or what not lol] or a starting byte from which to begin (and rest is all compressed, too).  Maybe just do global compression tho
#ltodo: if you get it fast, don't even list yourself.  They'll get it fast, too
#todor: a graph of increasing load on the x (well well connected server), with two lines, one that always immediately goes to p2p, and one that doesn't, to show this (will you need a medium size or large file?).  I'd anticipate this line being lower for p2p then crossing where the p2p overhead becomes worth it.

#ltodo: set's stop setting if you're done lingering :)
#ltodo: diff's for http (oh wait they already do...) but maybe look at it.

#ltodo: request 'till next got byte' to reuse connections
# TODOR gnuplot equiv. of graphs
# ltodor todor small -- fix on win32 its file writing crud
# ltodo have a 'failed' state that will close it with the outside when our internet doesn't work
# TODOR re-use the local server port per running instance (could just have the planetlab testers request a certain version or something)
# ltodo delete files should things end...abruptly
# ltodo use all the same file
# ltodo we don't take into account if 2 people are downloading from proxy, one leaves, nor re-linger
TEST_TIMEOUT = 60
# ltodo tell ruby '\\' doesn't seem to generate a single \
# these should all pre-load, afaik
# ltodo sub-blocks, or at least only one connection with the origin (partially implemented already)
# ltodo the multiple file thing...yeah... just use 70K 10K blocks instead [approximates it, in my opinion, except for order, so...reasonably close.]
# ltodo take into account that if one is deemed 'useless' then it still goes forward, filling bits, and might overtake another--and the first will have declared itself dead and subsequently puff out, and the second will notice itself overtaken and puff out.  Perhaps appropriate fix would be 'if I ever write something as being useful after not, then set a flag to restart when I puff out, or add me back to the pool for this block [latter better]' TODOR
#ltodo double check if killing is ineffective (i.e. if I'm hurting myself with the race, as origin still wins) also could/should 'request all' or 'request up to next filled byte' or what not.
# ltodo when connecting to the origin do you want to have a longer wait time? Does it matter?
# ltodo satsify http/1.1 constraints
# the 'todos' for me would be fast peer choice [checking peers actually ends up being pretty fast, so...eh...], pre-caching peers, and sub-blocks.
# ltodo possible to use HTTP/1.1 305? 'go use this proxy'?
# ltodo check if we need the various things for last block
# ltodo lookup ip's for schizo, how do they do that vs. ilab?
# ltodo test 10 download, put selves in DHT, we get the file fast (ha ha)
# ltodo just do all the blocks at the same time! Why wait!
# ltodo vote to delete people from openDHT [as we can't have a tracker that validates they live...] (?)
# ltodo would lessening the ruby overhead help?  All those writes...or the logging overhead?
# ltodo fix that percentile-> graph received from peers problemo.
#

$LOCAL_PEERS_OK = true
if Socket.gethostname == "melissa-pack"
  $dhtClassToUse = LocalDriveDHT
  $LOCAL_PEERS_OK = true # ltodo add this too :)
end
# ltodo it would be interesting to experiment with flashget with a single hop wireless at the end versus wired, and see why it is faster, and also perhaps design a transport protocol on UDP to alleviate problems, or make a single transfer as fast as multiple.  Also see if flashget is faster (MTT) with wired, as well, on DSL.
# ltodo a protocol that allows you to just post one web page then the next for your transmissions, to connect them--just get two web servers serving and you are set :)
# ltodo in reality we should open a port, AND request the file, and start to get data, before we trust that ti gives us anything...
# ltodo future work a registering backoff, too...hmm...yeah.
# #ltodo note that in versio n84_05_00 there are ThreadError's that are so so weird!
# tell ruby to include a File::BINARY as FFFF (?)
# ltodo writeup Ever click on a link and it just seems to take forever?
# ltodo writeup logarithmic backoff, or geographic logarithmic
# # ltodo writeup also cache dynamic, just for fun, or an algorithm 'hey that ain't really dynamic! it's cacheable!' or 'everything except X is cacheable!
# # # ltodo timeout's error needs to inherit from standard, or else things like open-uri don't get caught as nicely...maybe open-uri should catch it ?? or it should change?
# ltodo writeup try to use the 'latest' listed peers first (or something) to combat low linger time, which low linger time causes thrashing, which can confuse peers with slow openDHT speeds
# # ltodo writeup maybe make plugins for flashget or azureus that do this [list http mirrors, get from them, too, automatically]
#ltodo writeup http://torrent.ibiblio.org/doc/93/torrents is confusing, too!
# ltodo pass the original 'origin conn' around from CS to p2p, like a hot potato, to not lose its connectivity!
# ltodo a graph of 'percent received by peers as you vary one parameter' -- may already exist
# ltodo suggest there needs to eventually be a way to split the load more evenly than the 'first 10 still listed just get hammered'
# ltodo suggest that ruby have a 'readall' for tCPSocket
# # ltodo pass the original 'origin conn' around from CS to p2p, like a hot potato, to not lose its connectivity!
# ltodo http/1.1 continues :)
# ltodo replace kills with raises, ummm...ummm...cleanup threads, basially.
# ltodo replace raises with state checks phew! or kills, one of the two!
# ltodo tell putty 'scroll if on bottom only' option :)
# ltodo opendht optimization of not using PM :)
# ltodo publish my cygwin sleep scripts...ahh...:)
# ltodo resolve-replace should replace the peer-addr stuff!
require 'lib/logger' # ltodo with driver on first use, ask first if they have anything running... :)
require 'lib/block_manager'

#ltodo The real problem is that normal http downloaders do not insert themselves as 'seeds' in the torrent download [requiring a change at both client and server to work].
#
#ltodo Osprey does it the other way around.
#
# ltodo 'reuse' the same serving port
# ltodo 'optional' second (publicly accessible) IP+port to replace first
# ltodo 'save on dht as file x'
# ltodo: more token types?
# ltodo per mirror have tokens (?)
# ltodo: how many is fastest on origin?
# ltodo: able to pass in via url other peers, mirrors, etc.
# ltodo: super charge existing+future (same zact download of slower file, started earlier, gains mirrors) -- so it doesn't start second download.

#ltodo suggest new http header 'have these parts of the file' then we almost match BT with little effort, no funky protocols. or could re-use the "accept-range: bytes" to be "accept-range: x-partial-bytes[list]" and keep it already [kind of extension]
# ltodo new headers for 'have these blocks.'
# ltodo new request for 'want theis block then this then this'
# ltodo use the dht, and have a 'negotiation proxy' that is public IP +(UPNP+-STUNT)+-voluntary real proxies
## ltodo only write the file size if you go to p2p--makes sense to ma!
## ltodo with opendht use the faster server smore often
# ltodo have a better listing, more random, etc...
# # # ltodo with servers make them resilient to restart [listener, too, why not? :)] on rescue, restart it :)
# ltodo put in a statement that each log file always ends well :)
# ltodo with 'http only' double check those logs carefully for any p2p related actiity, nuke :)
# ltodo use $production = false
# ltodo run timeself on p2p server, optimize :)
# ltodo opendht use close guy for sets/rm's
# ltodo putty with 'very large scrollback' is weird...
# ltodo do not immediately drop your connection with the origin on switch to p2p
# ltodo don't pre-calc the ruby forge gateways unless you're a real client :)
# ltodo in one of first 2_000's, some took 500s for the erring guys...umm...uh...all princeton guys...umm..
# ltodo tell Ruby it would be nice to output, on death, all threads still running' status/backtrace
# ltodo a correlation between 'slow opendht and slow download speed' graph
# a 'streaming tree out' for the first block would probably be faster for those few bytes, but...how to choose the origin hosts?  some way to coordiante for the first block would be nice.
# ltodo with the origin backoff put a tim in there, and then...give them...you know...10s to get it or something :) -- I think that means a DHT timeout? [when we do the origin per block limit
$localAndForeignServerPort = 7779 # 8+ is apache
$PRETEND_CLIENT_SERVER_ONLY = false
$getAllAtBeginning =false# grundled, actually it is 'get them all at once each time'
$useOriginBackOffOrNumberConcurrent = 1000000 #1 or higher set to 1000000 (to avoid a short openDHT wait) and no limit
$allListenersPort = 20005
$verifyIO = false
$useOriginRevertOptimization = true # edit here, ltodo move to Driver
$p2pSkipCS = false  # deprecated
$doNotInterruptOriginThreadButYesP2P = false # if I want to turn that off...should mimic (cept for file size download) CS in speed...in theory :) [shows the impact of the CPU being loaded...]
$USE_MANY_PEERS_NO_SINGLE_THREAD = false # ltodo change this only in driver.rb! this is weird...umm...this should 
# ltodo kind of contorted if listener actually uses this ugh
# ltodo umm...on lefthand run it CS vs. p2p 20vs. 20 secs'...ummm...compare the server is it choking us too much, perhaps?

# ltodo so...we get behind in trying peers (esp. slow linger), and suddenly we're swamped with all this old garbage, we have to (get to) wade through it--it's legit, even--with a small linger time. ltodo overcome
# ltodo tell stunt people to have a 'natted' demo server, for real connecting!
# 53 no blocking for good opendht's -- read the other guy's :)
# 52 opendht something no pm's :) one opendht retry
# 51 multi block
# 50 precalc opendht
# 47.7 added sleep to p2p cycle...others...
# 48 no retries on opendht [bug fix], same
# 47 no last block fix, yes opendht fix, bugs all dead
# 46 bug fixes [reports now, etc.]
# 45 new timeout, opendht hopefully works (same as 44)
# 44 bug fix worked, still have opendht bugs [dht gets .44 or something!]
# 43 is no last, yes open, slowed down
# 42 is no last block, yes opendht, way buggy
# 41 has some debugging junk in there, too, is broken
# 40 is p2p pretending to be cs [broken opendht]
# ltodo fix the scenario of 'at 99% go to p2p' -- ridiculous! These need to be leveraged to complement each other
# ltodo writeup with a single long list openDHT can develop overCapacity errors--some method of splitting it up would be nice

# it appears that threads and Ruby do not play nice.  If one thread can go--it will go for like a full cpu second before being interrupted # that is NOT good.
# ltodo to ruby : - new binary operators "is within"
# ltodo tell ruby variables? would be nice
# ltodo investigate the opendht 'block 8 longer' question :)
# ltodo ruby timeout update submit, ask questions

# ltodo look into flush -- do we NEED to use it?  I think we only need to flush when truly necessary
# ltodo writeup note that this could replace DNS muhaha [it's kind of like shared DNS!] -- except you can have truly arbitrary names, and it's insecure
# ltodo ARGVInvalid in logger -> ruby ...

# ltodo graph with total system throughput with server throughput under
# ltodo individual real graphs with just one peer's stuff on it. Fascinating. kind of.

#ltodo do the eof 'controlling' ruby bug listed in the tracker :)
#ltodo suggest a tcp + piggyback is faster
## tell ruby this should work:  assert !runStyle.contains? "peersPerSecond"
# ltodo tell ruby a real 'flatten -> ary' would be nice (or doe sit exist?)
# ltodo publish scripts on how to superstart, etc.
# ltodo download http://download.oracle.com/berkeley-db/db-4.5.20.tar.gz
# ltodo right now with opendht we do maneuvers to be able to query only valid servers--fix it so that an invalid server will not crash us egh, then take out


# ltodo compare self with akamai
# ltodo writeup see what BT/Azureus do to leverage the DHT
def clientHasGraphLibraries
  begin
    require 'rubygems'
    begin
      require 'RMagick' unless Object.constants.grep(/Magick/).length > 0
    rescue LoadError
      require 'RMagick'
    end
    require 'gruff'
  rescue LoadError
    return false
  end
  return true
end 

#vltodo...compare rubies :) I think it's not our bug, though...the only
# ltodo compare opendht with more and more return values -- slower and slower, I'd imagine!

Thread.abort_on_exception = true # if a thread dies, tell me :)
Socket.do_not_reverse_lookup = true

if not defined? breakpoint
  def breakpoint
    print "WARNING BYPASSING BREAKPOINT YOU ARE NOT RUNNING RDEBUG or something\n"
  end
end

# ltodo fix the scenario of 'at 99% go to p2p' -- ridiculous! These need to be leveraged to complement each other
# ltodo writeup with a single long list openDHT can develop overCapacity errors--some method of splitting it up would be nice
# vltodo examine ruby itself -- one thread is writing to a file [write,write,write]...double check is that efficient? shouldn't that use about 100% cp[u?]
# ltodo move to some file 'useful classes' or something

def assertP2PFatality bool, message = nil
  message ||= "p2p assertion failure"
  if not bool
    raise P2PFatalityBad.new(message)
  end
end

class P2PWebFailure < StandardError
end

class TooSlowOnFirstBytes < P2PWebFailure
end

class GlobalCSTimeUp < ::P2PWebFailure # ltodo can we not move these to their respective files???
end

class AllBlocksDone < P2PWebFailure
end

class ClientSummarilyDroppedUs < P2PWebFailure # ltodo why no worky inside server classy?
 end

class P2PWebFailurePerhapsTemporary < P2PWebFailure
end # ltodo rename failure message or something


class P2PTransferInterrupt < P2PWebFailure
end 

class CSInterrupt < P2PWebFailure
end

class DTFailure < P2PWebFailure
end

class DRFailure < P2PWebFailure
end


class P2PFatalityBad < P2PWebFailure
end 

class P2PUndownloadable < P2PWebFailure
end

class LingerIsDone < P2PWebFailure
end
#ltodo ruby tell them ruby tester.rb with revision  767 shows that ensure's really might be nice
## ltodo tell ruby ensureCritical would be nice!
# ltodo 'future work' emule, or some method of discovering other http servers that happen to be serving
# the same file, use them also.  I don't know what emule is.  So mirrors, emule, some maneira to find mirrors
# (extension would be 'by block' -- japan.jp/abc.html:1000-1150 == go.com/yo.php:100-250)
# also good would be send bz2, and send diffs (google killer).
# also might be nice to store < 500B files on the DHT (why not?)
# or store on the DHT the diffs from version to version (like SVN and zsync diffs)...if small...then you can update yourself :) DHT keep me up to dater

# ltodo  the case of the 'one peer on the origin' contacts a really slow peer -- they need to grab only after their first loop through!
# ltodo profile code [why sucking so much?]
# ltodo super optimize verify :) [all one add]
# ltodo replace mkpath
# ltodo tell ruby they need configurable default backytraces (configurable--no snipping!)
# ltodo to rails:
# problems: a poor plugin can disable entire server
# it has its problem
# it doesn't report it well
# # ltodo sugest that ruby be able to redefine ==, +=, / , or, etc.
#ltodo add to notes: never use ruby the machines are too hammered for inefficiencies like this language


# ltodo: p2p server should probably not accept too many connections
# ltodo easy require of gruff...easier :)
#
# how to do gruff: require your own base.rb before anything, go to their base.rb and delete only teh contents (as they each tend to still include...the real base)

# ltodo with tests make them autonomous ... non needing help... :)
# with driver testself make sure that it doesn't use too large a file ;)
# ltodo run test with 10K server speed--shouldn't each client be getting 50K/S
# ltodo global overall download speed container within, for fun (we calculate it later, but...)
# ltodo listener 'message clear blocks'

# ltodo tell ruby -- seems that when you just have 80 threads all polling trying to send it takes 20% of CPU. That ain't good.
# ltodo optimization some type of dht caching might be *very* nice and important [like give the old get, and off-line do another] 
# ltodo put listener logs in right folder

# ltodo if you do have 'too many incoming' peers and cut them return a real 502
# ltodo a better listener [faux, restart] ltodo random filenames for 'yes generate', restart with 'these peers are in process' [load from their blocks]
# ltodo listener if zero whatever's (answer) complain if more than 0 threads
# ltodo optimization of 'one opendht get -> a right peers immediately [one DHT RTT...]
# ltodo optimization of 'only get a few'
# ltodo some type of back off on the main server--whether exponential or not, or just opendht based.
# ltodo test if rdebug assigns to next line [for ruby bug reports]
# ltodo test if you can breakpoint 'after' a function, then say 'eval' it and it breaks, for ruby-debug bug report
# ltodo fight [can test with slammed localhost] the discrepancies in timing -- is it more than just beginning time?  Should we mark them each time?
# vltodo test 'this dies on windows!' slammed localhost

# ltodo (at home) run with 10 guys in 10 seconds--umm...shouldn't that be faast?
# ltodo bh510jn -> pack
# ltodo with p2p_server make it 'pre-load' from disk the 'next block' ha ha
# ltodo better naming schema--filename + 10 digits :) -- vltodo? too annoying, doesn't allow for mod_rewrite...hmm...
# ltodo when we are downloading p2p+ simultaneous origin...do we report all the bytes coming in?  Are they all accounted for?
# ltodo test our download (server) against apache for those large files :)
# ltodo future .sig, and also digital signatures, other forms of hashing.

# ltodo with server instantaneous graphs spread it out over more than just one second :)

# ltodo three optimizations: one recurring to origin host, two back and forward [with origin, no dT], three 5 'fastest' incoming, four lesser load on the server
# todor test against CS, do writeup
# # todor test with 'basic' then the effect of each optimization
# todor test parameters [i.e. vary parameter]
# todor test against BT
# todor run it with dT .001 to be 'only p2p always' and see if it is fastest :)

# ltodo bluehost php version :)


#ltodo RoR eventmachine + thread pool+early instantiation. Done.
#ltodo tell ruby about dynamic class loading not working (!)
#bad file descriptor on files, after awhile (ugh)

# ltodo use BigDecimal by default (tell ruby) [advertise]

# socket creation/binding with Ruby objects is not thread safe. [perhaps]


# ltodo: mirror listings [or something]
# ltodo: ruby 1.9
# ltodo: could share it asynchronously by establishing a second 'call back' port where "I'm the server now!" or what not.  

# ltodo report to ruby 'sometimes it freezes'  ! Like just frozen! [win32] v. 183
# ltodo report to ruby 'sometimes exceptions escape!' [win32] [linux once, maybe?]
# ltodo report to ruby 'sometimes streams get switched!!!' [linux+win32] [lookup ruby torrent to see if already discussed]
# ltodo ruby version 172 to ruby: has two places where not a socket are thrown -- the incoming p2p server [possibly my fault, but before I close it...], and then again HTTP origin socket also does it every so often "suddenly not a socket!"
# ltodo possibility to ruby sometimes permission denied errors thrown on file delete, and MUST be in error or something is WRONG(?) [172]
# sometimes socket "accept" says "this is not a socket" [172]
# sometimes socket "accept" says "argument invalid" or something like that, in error. [173]
# on file close says some error (bad file descriptor) then deletes the thing [this is somewhat similar to "this is not a socket" then the file is deleted. C problem? [172]


#ltodo with peers on DHT put in your peer number, then we can say 'peer x died' or what not.
#ltodo accept better #'s in the host list, trim the 'lousy' hosts.
#ltodo tell ruby to do lazy dns reverses!

# ltodo interesting would be to have an 'omniscient' version (just tell me who has it! Always! Now!) and compare :)
#this so I can throw better
# ltodo  tell planetlab that when there's only 5G left, then give only a percent to each person (similar to bandwidth?) so that everybody still has SOMETHING to write to 
  # ltodo is there the race problem of creating it but not setting it to the variable?
  # ltodo set it so gruff works out of the box [assuming rmagick is installed]
  
  #15K main page
  #50K images
  #level1 295B
  #print.cs 1670
  #home.cs 758B
  # ltodo tell ruby (if there's not) an option to have the 'full' stack trace on blowup/shutdown or what not 
  # lodo tell ruby a temporary name resolution failure' seems to hang all threads.
  # lodo report ruby resolv doesn't work with localhost [ugh], and also that MX bug.
  # lodo look if nx could speed up http somehow through some magic means
  # ltodo ftp support ha ha
  # ltodo http proxy stylize (?)
  # point out how awful BT is at downloading the things we WANT
  # ltodo a better 'how many on the host' counter--either timing them out or marking them [glboal timing] or disdaining them after awhile--whatever.
  # real todo optimizations:
  # +somehow just get the 'end' 16K chunks or what not, of blocks [bool to download function?] 'you HAVE to download that chunk, and quickly' 
  #
  # duplicated chunks with streaming req's would be the best (lodo + "keep alive the connection," "pre-streamed" style stuff)
  #
  # +server limited conn's
  #
  #
  #
  #
  #
  #
  # Include one picture of 'naive'
  # one picture of 'origin reversion'
  #
  #
  #
  #
  # Contributions of this thesis:  We have shown how to use a generic DHT to drive a scalable p2p web cache system. 
  #
  # #
  # submit
  #     def rbuf_fill
  #           if IO.select([@io], nil, nil, @read_timeout)
  #                   @rbuf << @io.sysread(16384)
  #                         else
  #                                 raise Timeout::TimeoutError
  #                                       end
  #                                           end
  #
  #                                           to net/http with the 16384 in other spots, too.
  #
  #
  #                                           tell ruby of this
  #    tlodo production: allow for 192.168.1.whatever
  #    gzip it
  #
  #
  # having dual homed seems to slow down th emedian, and speed up the 99th percentile...hmm....I'd call it good overall, then. Also seems to make the gets more useful, and the system more stable overall.
  #
  # things to test in high detailed: dual homed/dual gatewayed (makes a difference? ideal value?)
  # grudndled
  # the backoff of the origin--is there an ideal time? does it/would it help?
  #
  #
  # ltodo with real proxy it will work--just only return the file part to the peer, not stdout :)
  # ltodo compare with Codeen, coral, with opendht set to its normal (unoptimized dynamic lookup)..(?) ask
  # ltodo EventMachine can it be a drop in replacement for socket, to kill socket's bugs?
  # ltodo fix cs does some gets still (ugh
  #
  # 751. tell ruby bug stack level too deep with this one running single
