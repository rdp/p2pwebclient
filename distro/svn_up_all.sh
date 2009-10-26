python vxargs-0.3.3.py --max-procs=150 -y --timeout=60 -a planetlab_hosts.txt -o vxOutForRe ssh byu_p2pweb@{} "cd p2pwebclient/src; . setup_env_planetlab_host.sh; svn up; killall -9 ruby"
