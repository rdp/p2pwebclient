require 'erb'
output = File.open 'httpd.conf.new', 'w'
@bandwidth=ARGV[0].to_i
output.write(ERB.new(File.read('httpd.conf.erb')).result(binding))
output.close
system "scp httpd.conf.new byu_p2pweb@planetlab1.byu.edu:/home/byu_p2pweb/installed_apache_2/conf/httpd.conf"
system 'ssh byu_p2pweb@planetlab1.byu.edu "/home/byu_p2pweb/installed_apache_2/bin/apachectl -k restart"'

