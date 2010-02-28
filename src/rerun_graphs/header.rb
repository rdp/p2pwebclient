require 'constants'
raise unless OS.posix?
raise '1.9.1 fork is broken' if RUBY_VERSION == '1.9.1'
require 'vary_parameter_graphs.rb'
