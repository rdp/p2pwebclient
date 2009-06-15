if [ `ps -ef | grep listener.rb | grep -v 'grep' | wc -l` == '0' ]; then cd p2pwebclient/src; . setup_env_planetlab_host.sh; svn up; nohup ./listen_forever.sh >> ../logs/listen_output_from_shell_small.txt 2>&1 < /dev/null & fi

