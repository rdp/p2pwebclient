python vxargs-0.3.3.py --max-procs=250 -y --timeout=40 -a planetlab_hosts.txt -o vxOutForShutdown ssh byu_p2pweb@{} "cd p2pwebclient/src; . setup_env_planetlab_host.sh; svn up; killall java"

