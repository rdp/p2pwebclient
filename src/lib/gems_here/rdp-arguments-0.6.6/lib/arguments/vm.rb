require 'ruby_parser'

module Arguments
  class PermissiveRubyParser < RubyParser
    def on_error t, val, vstack
      @rescue = vstack.first
    end

    def parse str, file = "(string)"
      super || @rescue
    end
  end
  
  def self.ast_for_method klass, method, am_self
    source, line = klass.instance_method(method).source_location
    
    lines = IO.readlines( source )
    
    remaining_lines = lines.length - line + 1 # 1 just in case...
    # because rubyparser is so picky...
    ast = nil
    remaining_lines.times{|n|
      str = lines[ (line-1)..(line + n) ].join
      ast = PermissiveRubyParser.new.parse( str )
      break if ast
    }
    if ast
      if am_self
        return (ast.assoc( :defs ) or ast)
      else
        return (ast.assoc( :defn ) or ast)
      end
    end
  end
end
