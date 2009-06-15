# enhanced arg parser for ruby

class Array
  
  # This function adds to ruby the ability to parse method parameters as if they were named.
  #
  # Benefits: named parameters are cleaner to use, decrease the number of bugs.  
  # They can also be entered in arbitrary order, so less hassle going back to figure out exactly which order was which.
  # They can also be passed as a hash, and so re-used from call to call.
  # It is a drop in replacement for existing Ruby, allowing for both required and optional arguments.
  # 
  # Basically, they make a cleaner, slicker, easier to read and use Ruby.
  #
  # drawback: small performance hit, auto-complete might not work as well on some IDE's [like we use that anyway], and you have to type the variable name in twice
  #
  #  doctest: basic syntax THESE TESTS ARE STILL HOSED
  #  >> def method1 *as 
  #        required1, required2 = as.args [:required1, :required2] # pass required arguments as an array of names
  #        end
  #  You can the call functions with or without named parameters, a la
  #   >> method1 1, 2
  #   => [1, 2]
  #   >> method1 :required1 => 1, :required2 => 2
  #   => [1, 2]
  #
  # It allows for optional parameters as well
  #  >> def method2 *as
  #      required1, required2, optional1, optional2 = as.args [:required1, :required2], {:optional1 => 3}, {:optional2 => 4}
  #      [required1, required2, optional1, optional2]
  #      end
  #  and use it:
  #  >> method2 1, 2, :optional2 => 5
  #  => [1, 2, 3, 5]
  #  >> method2 33, 44
  #  => [33, 44, 3, 4]
  # You don't have to use names [works with existing Ruby syntax]
  #  >> method2 33, 44, 55, 66
  #  => [33, 44, 55, 66]
  # But can use all names if desired for clarity
  #  >> method2 :required1 => 33, :required2 => 44, :optional1 => 55, :optional2 => 66
  #  => [33, 44, 55, 66]
  # 
  # you can mix the order, just note that once you start naming parameters, you can only use named parameters
  #  >> method2 :optional1 => 33, :required2 => 44, :optional2 => 55, :required1 => 66
  #  => [66, 44, 33, 55]
  #
  # and you can start with non-named and then use named
  #  >> method2 11, :required2 => 33, :optional2 => 77
  #  => [11, 33, 3, 77]  
  # note that you can also use and re-use hashes as parameters
  #  >> opts = {:required1 => 11, :required2 => 22}
  #  >> method2 opts
  #  => [11, 22, 3, 4]
  # now re-use parameters
  #  >> method2 opts
  #  => [11, 22, 3, 4]
  # compatible as a drop in replacement for existing methods:
  #  def method3 a, b, c, d = 4
  # ...
  # becomes [without changing the way it is called anywhere]
  #  >> def method3 *as
  #      a, b, c, d = as.args [:a, :b, :c], {:d => 4}
  #      end
  #  >> method3 1, 2, 3
  #  => [1, 2, 3, 4]
  #
  # advanced use:
  # it can also replace existing params "partially" -- say you want to be able to pass you last 2 parameters with names, of an existing function
  #  def method5 a, b, c, d
  # becomes
  #  >> def method5 a, b, *as
  #      c, d = as.args [:c, :d]
  #      [a, b, c, d]
  #      end
  #
  #  >> method5 1, 2, :c => 3, :d => 4
  #  => [1, 2, 3, 4]
  #
  # what if you used to use a hash as your last parameter? (You still can, you just have to change it to pass a named parameter for the ending hash)
  #  doctest: example with a last hash
  #  >> def uses_ending_hash *as
  #      param1, options = as.args [:param1], {:options => {}}
  #      end
  #
  #  >> uses_ending_hash 3
  #  => [3, {}]
  #  >> uses_ending_hash 3, :options => {:be_aggressive => true}
  #  => [3, {:be_aggressive => true}]
  #  >> uses_ending_hash 3, :options => {:be_aggressive => true, :force => true}
  #  => [3, {:be_aggressive => true, :force => true}]
  #  doctest: NOTE in some rare cases you have to monkey a little bit--if your default values cause side effects, it's overcomeable
  # old style was: def method4 a, b = a * some_method_with_side_effects # some_method_with_side_effects isn't run, normally, if you pass a value for b
  # new style: we'll accomplish essentially the same thing using ||=
  # 
  #  >> $count = 0
  # #count should increase only if we don't pass anything to b
  #  >> def method4 *as
  #      a, b = as.args [:a], {:b => nil}
  #      b ||= ($count += 1)
  #      $count
  #      end
  #
  #  >> method4 1, 2 # shouldn't increment
  #  >> 0
  #  >> method4 1 # should increment
  #  >> 1
  #  >> method4 :a => 2 # should increment
  #  => 2
  #  >> method4 :a => 1, :b => 2 # should not increment
  #  => 2 # didn't increment
  #
  # see also the file enhanced_arg_parser.doctest.rb for more examples.
  #
  # future work:
  # ltodo optimize for speed -- some of these run-time checks may not be necessary, especially except in development :)
  #
  # ltodo: move into C if possible :)
  #
  # ltodo: verify against classes, too, like dynamic type checking, only if the user desires.

  def interpret_args *settings_array
    # self will be [1, 2, {:optional_2 => 7}]
    # or 	   [1, {:req_2 => 2, :optional_2 => 7}]
    # or	   [1, 2, 3, 4]
    # or           [1, 2]
 
   # settings_array will be [], :optional_name, value, :optional_name2, value2
    
    args_passed = self.dup # clearer error messages this way :)
    all_assigned = []
    already_named_one = false
    
    # get any nameds from the ending hash
    ending_hash = args_passed.pop.dup # we can assume the ending arg will be a hash or we never would have been called
    requireds = settings_array[0]
    optionals = settings_array[1..-1]

    requireds.each_with_index{ |name, idx|
      if ending_hash.has_key?(name)
        all_assigned << ending_hash.delete(name)
        already_named_one = true #they 'have' to name everything after their first named one, or I guess there'd be ambiguity as to which they meant the one after their first named one to actually be....well...at least we'll pretend they have to :)  I guess the only thing is it causes them to get a cross-eyed as to the one that came next like arg1, this_ones_in_the_hash_actually, arg3_looks_like_arg2_unless_you_go_cross_eyed, hash_one_is_here_now!
      else
        raise MalformedArguments.new("missing #{name} (:#{name}) (index #{idx}) not enough or misnamed required arguments you passed #{self.inspect}") unless args_passed.length > 0 # have to do this one by one in case we hit one, above
        raise MalformedArguments.new("once you name one parameter you must keep naming the rest of the parameters (missing #{name}) #{self.inspect}") if already_named_one
        all_assigned << args_passed.shift
      end
    }
    # ltodo: test cases that cause all thrown exceptions

    until optionals.empty?
      name = optionals.shift
      
      if ending_hash.has_key?(name) # allow for default to nil TOTEST
        all_assigned << ending_hash.delete(name)
        # redundant with the ending raise, I think -- ? raise MalformedArguments.new("seems you passed a named parameter of a required one but still have some extra unnamed ones extra in there (on #{name.inspect}) or you didnt pass some that were required}") unless args_passed.length == 0
        already_named_one = true
      else # if there are still 'unused' unnamed variables then use them, else use the default
        if args_passed.length > 0
          raise MalformedArguments.new("once you name one parameter you must keep naming the rest of the parameters to avoid ambiguity on #{name}") if already_named_one
          all_assigned << args_passed.shift
        else
          all_assigned << :__wants_default_value
        end
      end

    end    
    raise MalformedArguments.new("unknown vars! #{ending_hash.keys.inspect} not in #{settings_array.inspect}") unless ending_hash.empty?
    raise MalformedArguments.new("too many vars! #{args_passed.inspect}") unless args_passed.empty? # can you ever even reach this?
   
    # if it's size one then only pass out one, not array 
    all_assigned.length == 1 ? all_assigned[0] : all_assigned # accomodate for abc = args.get :abc => 3 # which passes out an array and assigns abc an array if there's only one -- anyway with only one the outgoing array isn't split right -- is this still necessary?
  end

end

# class raised if param specifications are mal formed [like you don't pass enough, etc.
class MalformedArguments < ArgumentError; end;

