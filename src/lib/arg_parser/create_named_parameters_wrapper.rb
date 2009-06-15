=begin
+ltodo: allow for :use_file_for_new_code or something for 1.9 pretended compat.

Note that if you were to redefine a method after calling create_named_parameters_wrapper on it, the new method would also need create_named_parameters_wrapper to be called on it.  It overwrites the old one.

Todo: work with '*args' :) however that works.  Parse them off up front?
todo: combine the two files so we don't have to add an extra function in there

ltodo: c-ify the one function that can be :)

to note: it doesn't support [?] for initializations that declare new local variables, a la def method1(a, b = (d = 4)) # this is super weird, and not supported!
normal stuff is supported, a la
def method1(a, b = a)
or
def method1(a, b = 3, c = 4)

todo: disallow method1(a, b = c*4, c =5) -- shouldn't work since it's confusing as to which one gets initialized first! avoid bugs at all costs first! optimize later!

ltodo: add the function name itself to all raise args...unless that's not necessary :)
ltodo: take out the extraneous backtrace from generated errors... maybe :)
ltodo: add more verbosity to raised error messages -- like...an inspect of all the params, or what not [if possible]

ltodo: write to a file, save, and require that file [?]
ltodo: allow it to output a string if they want to just paste it into their code :)


note: having an ending *args currently doesn't work.  Having just *args by accident works [we just leave the function as it was, similar to if it has 0 args]

ltodo: support having those extra assigns in there...maybe :) That might not be possible!
ltodo: is there a more efficient way for 'which ones need their default values... I know--move the whole thing to C lol or maybe pass out a value...tough to tell...

ltodo: no longer add a helper to the Array class, since that is...so for ease of usability :)
 then we could have that MalformedArguments guy from ours

ltodo: include AutoAllowNamedParametersForThisClass

ltodo: re-use the parameter args as an array 'somewhere' even if it's just in AllowNamed::@idx2 [does that speedup?]

ltodo: optimize for speed/not creating objects.

ltodo: is the shortcut for just calling it without an ending hash...um...a good idea? that might not even work once I mix in the *args compensation code :)

ltodo: note --we raise if the default ending argument is a Hash, as that is not allowed, and you shouldn't expect one, anyway! Here's why...

ltodo: note that if they expect an ending {} that that will no longer work.  They will have to rename it.

ltodo: a function 'wrap all existing methods' which just wraps every 'apparently non inherited' method.
=end

require 'parse_tree'
require 'ruby2ruby'
require File.dirname(__FILE__) + '/enhanced_arg_parser.rb'

class Array
    def map_with_index!
       each_with_index do |e, idx| self[idx] = yield(e, idx); end
    end

    def map_with_index(&block)
        dup.map_with_index!(&block)
    end
end

class Array
  def to_ruby
    Ruby2Ruby.new.process(self)
  end
end

class Object

def create_named_parameters_wrapper name_as_symbol
 raise 'not yet 1.9 compat' if RUBY_VERSION.include? '1.9'
 args = nil
 is_class_method = nil

 begin
  if name_as_symbol.to_s =~ /^self\./ # class method has slightly different parse tree
    args = ParseTree.translate(self, name_as_symbol)[3][1][1] # an error here means 'the function is undefined' # ltodo clarify
    name_as_symbol = name_as_symbol.to_s[5..-1].intern # take off that self
    is_class_method = true
  else
    args = ParseTree.translate(self, name_as_symbol)[2][1][1] # an error here means 'the function is undefined' # ltodo clarify
  end
 rescue NoMethodError # no [] on nil
  raise "poor symbol name #{name_as_symbol} for #{self} == did you mean\nclass << self; create_named_parameters_wrapper :#{name_as_symbol}; end\n -- necessary for a class method?  or maybe the method is undefined?"
 end

 if args[-1].class == Array
    optionals_assignments = args[-1][1..-1] # avoid the :block beginner
    variable_names = args[1..-2]
 else
    optionals_assignments = []
    variable_names = args[1..-1]
 end

 return if variable_names.length == 0 # so don't have to worry about it :) -- this also the case if they have *args, I think, which we don't want to handle, anyway, and they already handle, so overall, it's ok to return :)

 # now do some checks to make sure they aren't passing us anything weird

 # todo: really handle *args
 raise 'not yet accomodated' if variable_names[-1].to_s[0..0] == '*' # we don't yet handle *args

 raise 'dont support ending hash as a default value for the last parameter--this could cause confusion for if you were to pass barely misnamed parameters--is that hash supposed to be the ending value or not? for ' + variable_names[-1].to_s  if optionals_assignments != [] and optionals_assignments[-1][2][0] == :hash

 for assignment_code in optionals_assignments
   raise MalformedArguments.new('we don\'t support extra assignments within the default values yet ' + assignment_code.to_ruby) if assignment_code[2].flatten.include?(:lasgn)
 end
 raise "unclear if it works with your current ruby scope. Feel free to comment this out if you think it will.  If you are running within class << self; ... end; block then please run it outside of that block, like allow_named :'self.function_name'" if self.to_s =~ /^#<Class:/ # error check for this odd case which causes some scope problems, a la your initailizations cannot see @@variables! ltodo overcome
 # to note: note that you can't run it within class << self--at least not currently.

 number_of_requireds = variable_names.length - optionals_assignments.length
 requireds = number_of_requireds == 0 ? [] : variable_names[0..(number_of_requireds - 1)]  # if it's zero then it ends up taking the entire array :)
 optionals = variable_names[number_of_requireds..-1]
 #for optional in optionals do; raise '*args not yet supported, sorry' if optional == :"*args"; end # sanity check, for my own sake

=begin

We want to generate a new method that is an arg pre-processor for the specific, a la

def go(a = 2, b = 3)

alias :original_go :go

def go *args
 a, b = args.parse [], :a, :b,
 if a == :__wants_default_value 
   a = 2
 end
 if b == :__wants_default_value
   b = 3
 end
 original_go a, b
end

=end

 if is_class_method
    alias_string = "class << self;   alias :_#{name_as_symbol}_ :#{name_as_symbol}; end"
 else
    alias_string = "alias :_#{name_as_symbol}_ :#{name_as_symbol}"
 end

 wrapper_func_string = <<-END
  #{alias_string}
  def #{self.to_s + '.' if is_class_method}#{name_as_symbol} *args
     if args[-1].class != Hash # an optimization :) 
	if block_given?
		return _#{name_as_symbol}_(*args) { |*args| yield(*args) }
	else
		return _#{name_as_symbol}_(*args) 
	end
     elsif args[-1] == {} # yet another optimization -- if they don't pass any nameds...we don't need to parse anything [cleanup]
       if block_given?
              return _#{name_as_symbol}_(*(args[0..-2])) { |*args| yield(*args) }
       else
              return _#{name_as_symbol}_(*(args[0..-2]))
       end
     end

     #{variable_names.map{|name| "#{name}"}.join(',')} = args.interpret_args [#{requireds.map{|r| ":#{r}"}.join(',')}]#{optionals.map {|name| ", :#{name}" }}

     # erring within these intializations with something like 'NameError: uninitialized class variable @@default_dht_class in Object' might mean 'you are running it within class << self -- you want to run allow_named_parameter :'self.name' instead--and not in that block.

     #{optionals.map_with_index{|optional, idx| "if #{optional} == :__wants_default_value then; #{optionals_assignments[idx].to_ruby}; end"}.join("\n     ")}
     if block_given?
       _#{name_as_symbol}_(#{variable_names.join(',')}) { | *args| yield(*args)} # call it, implicitly return its return value
     else
       _#{name_as_symbol}_(#{variable_names.join(',')})
     end
  end
 END

 begin
   Dir.mkdir '.named_wrappers' unless File.exist? '.named_wrappers'
   filename = ".named_wrappers/#{self}-#{name_as_symbol}-autocreated-#{args.hash}.rb"
   a = File.new filename, 'w'
   a.write  wrapper_func_string
   a.close
 rescue Exception => e
   # ignore for now
 end
 self.class_eval wrapper_func_string, filename, 1

 # note that your own functions will always be called with values, now, as they are assigned all the default values [as specified] in the calling arg pre parser method.
 # i.e. if you do def method1 (a, b =1) # the b = 1 assignment will actually take place in the method before, and it will be passed as (a, 1) 
end

end
