  class HeadRetriever < EventMachine::Connection
    def init fullUrl, parent, logger, done_proc
      self.set_comm_inactivity_timeout 90 # try and avoid a weirdness where at least once, a head request went out and [EM didn't handle it?] never came back
      @done_proc = done_proc
      @parent = parent
      pageStringOnly, hostToGetFrom, ipPortToGetFrom = TCPSocketConnectionAware.splitUrl(fullUrl)
      requestString = TCPSocketConnectionAware.createHTTPHeadRequest(pageStringOnly, hostToGetFrom, ipPortToGetFrom)
      send_data requestString
      @startTime = Time.new
      @logger = logger
      @logger.debug "starting HEAD request"
      @done = false
    end

    def connection_completed
      @logger.debug "HEAD conn completed -- AND we already queued the HEAD request, itself, so we're ready to receive it, now"
    end

    def receive_data received
      amPastHeader, returnable, currentTransmissionSize, totalFileSize = TCPSocketConnectionAware.parseReceiveHeader received
      totalFileSize ||= currentTransmissionSize # for those that pass it to us as Content-Length
      @logger.debug "tcp HEAD set length to #{totalFileSize} after #{Time.new - @startTime}s"
      if totalFileSize
        @parent.setFileSize(totalFileSize)
      else
        @logger.error "huh no head in #{received}"
      end
      close_connection
      done
    end

    def done
      return if @done
      @done = true
      if @parent.fileSizeSet?
        @logger.debug "HEAD request success"
        @done_proc.call(:success)
      else
        @logger.debug "HEAD request unbound early!!!"
        @done_proc.call(:failure)
      end
    end

    def unbind
      done
    end
  end
