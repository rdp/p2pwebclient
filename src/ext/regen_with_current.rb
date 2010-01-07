dir =  'em/' + RUBY_VERSION + '.' + RUBY_PLATFORM
Dir.chdir '../lib/gems_here/eventmachine_my_clone/ext' do
  system("ruby extconf.rb")
  system("make clean")
  system("make")
end
system("cp ../lib/gems_here/eventmachine_my_clone/ext/*.so #{dir}")
