python vxargs-0.3.3.py --max-procs=250 -y --timeout=40 -a planetlab_hosts.txt -o vxOutForShutdown ssh byu_p2p@{} "killall -9 ruby; killall java; killall /bin/bash; killall -9 /bin/bash"

