python vxargs-0.3.3.py --max-procs=250 -y --timeout=40 -a planetlab_hosts.txt -o vxOutForShutdown ssh byu_p2p@{} "cd p2pwebclient/src; . setup_env_planetlab_host.sh; cd lib/opendht/bamboo; git pull"
