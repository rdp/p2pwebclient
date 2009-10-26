#!/bin/bash
ssh byu_p2pweb@planetlab1.flux.utah.edu "cd p2pwebclient/src; . setup_env_planetlab_host.sh; ruby set_remote_server_speed.rb $1" 
