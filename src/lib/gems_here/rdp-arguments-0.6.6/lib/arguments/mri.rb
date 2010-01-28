gem 'ParseTree', '>= 3.0.3'
require 'parse_tree'

module Arguments
  def self.ast_for_method klass, method, am_self
    # don't care about am_self for 1.8.x (ParseTree)...
    ParseTree.new.process(ParseTree.translate( klass, method ).assoc(:scope).assoc(:block))
    # the #process call is to clean up a "raw" tree, apparently, as ruby2ruby later expects a "unified" tree
  end
end

