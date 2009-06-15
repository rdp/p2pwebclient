require 'rubygems'
require 'mongrel'

 class SimpleHandler < Mongrel::HttpHandler
    def process(request, response)
      response.start(200) do |head,out|
        head["Content-Type"] = "text/plain"
        out.write("hello!\n")
      end
    end
 end

 h = Mongrel::HttpServer.new("0.0.0.0", "3000")
 h.register("/test", SimpleHandler.new)
 h.register("/", Mongrel::DirHandler.new("."))
 h.run.join
