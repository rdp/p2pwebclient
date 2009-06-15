python vxargs-0.3.3.py --timeout=600 -a planetlab_hosts.txt -o output/install_all2 ssh byu_p2pweb@{} "wget http://wilkboardonline.com/roger/p2p/i386.tar.gz; tar -xzf i386.tar.gz; rm i386.tar.gz; ~/i386/bin/svn checkout http://p2pwebclient.googlecode.com/svn/trunk/src p2pwebclient/src; mkdir p2pwebclient/logs; "

