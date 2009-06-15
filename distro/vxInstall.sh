#ssh byu_p2pweb@planetlab-10.cs.princeton.edu "sudo yum install ruby -y; sudo yum install subversion -y; svn checkout http://p2pwebclient.googlecode.com/svn/trunk/src p2pwebclient/src; mkdir p2pwebclient/logs; cd p2pwebclient/src; nohup ./listen_forever.sh &"
python vxargs-0.3.3.py -a top20.txt -o vxOut ssh byu_p2pweb@{} "sudo yum install ruby -y; sudo yum install subversion -y; svn checkout http://p2pwebclient.googlecode.com/svn/trunk/src p2pwebclient/src; mkdir p2pwebclient/logs; cd p2pwebclient/src; nohup ./listen_forever.sh &"

