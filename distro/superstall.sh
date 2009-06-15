# installs it on clients that are found to not currently have a copy
python vxargs-0.3.3.py -y --plain --timeout=1600 -a planetlab_hosts.txt -o output/superstall1 ssh byu_p2pweb@{} "if [ ! -f "~/p2pwebclient/src/listener.rb" ]; then rm i386.tar.*; wget http://wilkboardonline.com/roger/p2p/i386.tar.gz; tar -xzf i386.tar.gz; rm i386.tar.gz;  ~/i386/bin/svn checkout http://p2pwebclient.googlecode.com/svn/trunk/src p2pwebclient/src; mkdir p2pwebclient/logs; fi;"

