export PATH=/home/byu_p2pweb/i386/bin:/home/byu_p2pweb/i386/jre1.6.0_07/bin:$PATH
mkdir -p ../logs/`ruby -e "require 'lib/ruby_useful_here.rb'; print Socket.get_host_ip()"`/
export LD_LIBRARY_PATH=./ext/planetlab_ilab # useful anymore?
export INLINEDIR='./ext/planetlab_ilab'
