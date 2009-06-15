require 'rubygems'
# unique require for ruby 1.8.x
# see README

if RUBY_VERSION < "190"
if(!defined?(Already_Loaded_Require_Unique))
Already_Loaded_Require_Unique = true
require 'pathname'
module Kernel
        alias :require_non_uniqe :require
        def require *args
		
                filename = args[0]
                for name in [filename, filename + '.rb', filename + '.so', filename + '.bundle'] do
		  if File.exist?(name)
	            full_path = Pathname.new(name).realpath
		    return require_non_uniqe(full_path)
                  end
                end
	        # now for library lookup it should be unique
		return require_non_uniqe( *args)
        end
end
end
end
# doctest: it should require files only once
# >> require 'pathname'
# >> $a = 1
# >> File.open('require_once.rb', 'w') do |f|; f.write '$a += 1'; end # write out a file that increments $a
# >> require 'require_once.rb'
# >> $a
# => 2 # it should increment it once
# >> parent_dir = File.dirname( Pathname.new($0).expand_path ).split('/')[-1]
# >> require "../#{parent_dir}/require_once.rb"
# >> $a
# => 2 # but not a second time

