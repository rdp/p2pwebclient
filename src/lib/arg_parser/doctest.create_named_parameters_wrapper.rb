# doctest_require: 'enhanced_arg_parser.rb'
require 'pp'
def go *args
  a, b = args.interpret [], :a, :b
  if a == :__wants_default_value
   a = 3
  end
  if b == :__wants_default_value
   b = 2
  end
  [a, b] 
end

# doctest: simple
# >> 3
# => 3
# >> go
# => [3, 2]
# >> go 4
# => [4, 2]
# >> go 4, 5
# => [4, 5]

=begin

doctest_require: 'create_named_parameters_wrapper.rb'
doctest: spec it out
>> def go3(a, b = 3, c = 34); [a, b, c]; end
>> Object.class_eval "create_named_parameters_wrapper :go3"
>> go3 3
=> [3, 3, 34]
>> go3 4
=> [4, 3, 34]
>> go3 :a => 55
=> [55, 3, 34]
doctest: raises requires requireds
>> go3 :b => 55
MalformedArguments: missing a (:a) (index 0) not enough required arguments in []
	from ./enhanced_arg_parser.rb:148:in `interpret'
	from (irb):88:in `each_with_index'
	from ./enhanced_arg_parser.rb:143:in `each'
	from ./enhanced_arg_parser.rb:143:in `each_with_index'
	from ./enhanced_arg_parser.rb:143:in `interpret'
	from (eval):2:in `go3'
	from (irb):88
doctest: you can swap values
>> go3 :a => 33, :b => 55
=> [33, 55, 34]
>> go3 :a => 33, :b => 55, :c => 45
=> [33, 55, 45]
>> go3 :a => 33, :c => 55
=> [33, 3, 55]
>> go3 :a => 33, :c => 55, :b => 45
=> [33, 45, 55]
>> go3 33, :c => 55, :b => 45
=> [33, 45, 55]
=end

class A

  def go(a, b, c = 3)
    [a, b, c]
   end

   create_named_parameters_wrapper :go
end

=begin
#doctest :works within a class def
>> a = A.new
>> a.go 3, 4, 5
=> [3, 4, 5]
>> a.go 5, 4
=> [5, 4, 3]
doctest: raises if you name things out of order
>> a.go 5, 4, :b => 5

MalformedArguments: once you name one you must keep naming to avoid ambiguity c
	from ./enhanced_arg_parser.rb:165:in `interpret'
	from (eval):2:in `go'
	from (irb):9

=end

def go4(a = 2, b = 3, d = 3)
 [a, b, d]
end

def go_with_assignments(a = 2, b = d = 3, c = 4)
end

=begin
doctest: works with all variable params [doesn't throw a fit if you don't name them, as it once did]
>> go4
=> [2,3,3]
>> go4(3)
=> [3,3,3]
>> Object.class_eval "create_named_parameters_wrapper :go4"
>> go4
=> [2,3,3]
>> go4(3)
=> [3,3,3]
doctest: raises if you have some assignments within your initialization code.
>> Object.class_eval "create_named_parameters_wrapper :go_with_assignments"
ItRaisesOnMe:
doctest: it works with all unnamed
>> def go5(a, b); [a, b]; end
>> Object.class_eval "create_named_parameters_wrapper :go5"
>> go5(1, 2)
=> [1, 2]
>> go5(1, :b => 3)
=> [1, 3]
>> go5(:a => 4, :b => 5)
=> [4, 5]

=end

def star_args(a, b, *args)
  [a, b, args]
end

# doctest: works with *args
# >> star_args(1, 2, 3)
# => [1, 2, [3]]
# >> star_args(1, 2, 3, 4)
# => [1, 2, [3, 4]]
# >> Object.class_eval "create_named_parameters_wrapper :star_args"
# >> star_args(1, 2, 3)
# => [1, 2, [3]]
# >> star_args(1, 2, 3, 4)
# => [1, 2, [3, 4]]
# >> star_args(:a => 2, :b => 3)
# => [2, 3, []]
# >> star_args(2, 3)
# => [2, 3, []]
# >> star_args(2, :b => 3)
# => [2, 3, []]
# >> star_args(2, :b => 3)
# => [2, 3, []]
# ltodo: it should raise with a WHOLE lot of other ones, currently, too :)
# ltodo: maybe allow ({:a => 1, :b => 2}, 3, 4, 5) -- however, this one is ambiguous for if that 3 means 'b' or not.
# and (1, {:b => 2}, 3, 4, 5)
# so you'd have to work forward, marking something as the 'restant' cache if it satisfies all remaining requireds

# I guess people can convert their current (a, b, *args) to (a, b, c) and pass in {:a => 2, :b => 2, :c => [3, 4, 5]}
# or (a, b, rest), {:a => 2, :b => 2, :c => [3, 4, 5]}
# doctest: TODO works with default values, *args

# doctest: raises if the ending values default value is a hash-- undefined
# >> def ending_hash(a, b = {}); [a, b]; end
# >> Object.class_eval "create_named_parameters_wrapper :ending_hash"
# ABadErrorMessage:
# doctest: raises if the ending values default value is a hash-- undefined
# >> def ending_hash(a, b = {:a => 4}); [a, b]; end
# >> Object.class_eval "create_named_parameters_wrapper :ending_hash"
# ABadErrorMessage:

# doctest: works with class methods, too
class A
 @@about = 'about'
 def A.go(b = @@about)
   b
 end
end
# >> A.go
# => "about"
# >> class A; create_named_parameters_wrapper(:'self.go'); end
# >> A.go
# => "about"
# >> A.go 2
# => 2
# >> A.go :b => 3
# => 3

# doctest: throws an error if you define one within class << self -- since you need to use 'self.method_name' instead
# >> class B
#      class << self
#        def go(a); end
#        create_named_parameters_wrapper :go
#      end
#      end
# SomeError:
