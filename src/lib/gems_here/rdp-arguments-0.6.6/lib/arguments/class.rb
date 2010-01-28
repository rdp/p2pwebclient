module Arguments
  def named_arguments_for *methods
    methods = instance_methods - Object.methods if methods.empty?
        
    methods.each do |meth|
      meth    = meth.to_s
      original_klass = self
      if meth =~ /^self\./
        am_self = true
        klass = (class << self; self; end)
        meth.sub!(/^self\./ , '')
      else
        klass = self
      end
      names = Arguments.names klass, meth, am_self
      next if names.empty? or names.inject(false) { |bol, pair| bol || /^\*/ === pair.first.to_s }
      assigns = []
      names.pop if /^&/ === names[-1][0].to_s
      
      names.each_with_index do |name, index|
        unless name.size == 1
          assigns << <<-RUBY_EVAL
            #{ name.first } =
            if opts.key? :#{ name.first }
              opts.delete :#{ name.first }
            else
              args.size >= #{ index + 1 } ? args[#{ index }] : #{ name.last }
            end
          RUBY_EVAL
        else
          assigns << <<-RUBY_EVAL 
            begin
              #{ name.first } = opts.key?(:#{ name.first }) ? opts.delete(:#{ name.first }) : args.fetch(#{ index })
            rescue 
              raise ArgumentError.new('passing `#{ name.first }` is required')
            end
          RUBY_EVAL
        end
      end

      it = <<-RUBY_EVAL, __FILE__, __LINE__
        #{ "class << self" if am_self } 
        def __#{ meth }_with_keyword_arguments *args, &block
          opts = args.last.kind_of?( Hash ) && args.size < #{ names.size } ? args.pop : {}
          #{ assigns.join("\n") }
          unless opts.empty?
            raise ArgumentError.new("`\#{ opts.keys.join(', ') }` \#{ opts.size == 1 ? 'is not a recognized argument keyword' : 'are not recognized argument keywords' }") 
          end
          __original_#{ meth } #{ names.collect{ |n| n.first }.join(', ') }, &block
        end

        alias __original_#{ meth } #{ meth }
        alias #{ meth } __#{ meth }_with_keyword_arguments
        #{ "end" if am_self }
      RUBY_EVAL
      if $DEBUG
        code, file, line = *it
        file = "cached_methods/#{meth}"
        line = 1
        Dir.mkdir 'cached_methods' rescue nil
        File.open(file, 'w') do |f|
          f.write code
        end
        it = [code, file, 1]
      end   
      original_klass.class_eval(*it)
    end
  end
  alias :named_args_for :named_arguments_for
  alias :named_args     :named_arguments_for
end

class Class
  include Arguments
end

class Module
  include Arguments
end