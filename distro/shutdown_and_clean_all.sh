python vxargs-0.3.3.py --max-procs=150 -y --timeout=40 -a planetlab_hosts.txt -o vxOutForShutdown ssh byu_p2pweb@{} "killall -9 ruby; killall ja_disabled_va; cd p2pwebclient/src; . setup_env_planetlab_host.sh; rm -rf lib/rev_trunk; rm -rf lib/arg_parser; svn cleanup; killall /bin/bash;"

