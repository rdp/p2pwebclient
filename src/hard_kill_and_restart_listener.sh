killall -9 ruby;  cd p2pwebclient/src; . setup_env.sh; svn up; nohup ./listen_forever.sh >> ../logs/listen_output_from_shell_small.txt 2>&1 < /dev/null &
