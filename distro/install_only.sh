python vxargs-0.3.3.py -y --timeout=600 -a planetlab_hosts.txt -o output/install_all2 ssh byu_p2p@{} "rm i386.tar.gz*; wget http://wilkboardonline.com/p2p/i386.tar.gz; tar -xzf i386.tar.gz; rm i386.tar.gz; wget http://wilkboardonline.com/p2p/p2pwebclient.tar.gz; tar -xzf p2pwebclient.tar.gz; rm p2pwebclient.tar.gz" # allow for updates on startup

