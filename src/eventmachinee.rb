require 'eventmachine'
module EventMachine
    def self.handle_runtime_error
      $>.puts $!
    end
 end
