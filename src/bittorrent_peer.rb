require 'socket'
class String
 def clear!
   self.gsub! /.*/, ''
 end
end

class BitTorrent
  # doctest: downloads with success [pre-req: start up tracker/seed right]
  # >> require 'constants'
  # >> logger = Logger.new 'temp_log', 30
  # #>> b = BitTorrent.new 'bittorrent/torrent.30000K.file.torrent', logger
  # >> b = BitTorrent.new 'bittornado/30000K.file.ilab1.torrent', logger
  # >> logger.read_whole_file.include?('SUCCESS')
  # => true
  # >> File.delete('temp_log')

  def self.get_config_directory
     if Socket.gethostname =~ /roger/
	'/Users/rogerpack/Library/Application Support/BitTorrent'
     else
	'/home/byu_p2pweb/.BitTornado'
     end
  end

  module BTWrapper
    include Logs
    def receive_data data
      if data =~ /SUCCESS/
          @successful = true
# put this here instead of in unbind since at least once unbind was never called...very odd...
	  @logger.log "Bittorrent download ENDED  in #{Time.now - @start_time}s SUCCESS" 
      end
      log data
    end

    def setup parent, download_name
        @parent = parent
        @download_name = download_name
        @start_time = Time.now
        @logger = parent.logger
        @log_prefix = "BT output"
        @successful = false
    end

    def unbind
        @logger.debug "unbind on BT peer"
        @logger.debug "resetting ~/.bittornado files"
        system("rm -rf '#{BitTorrent::get_config_directory}'")

        File.delete(@download_name) if File.exist? @download_name # how can it not exist? Yet sometimes it does--on error
        if @successful
	  @logger.log "unbind after BT success"
	else
	  @logger.log "Bittorrent download FAILED in #{Time.now - @start_time}s FAILURE" 
        end
        @parent.post_BT
    end

  end

  def self.do_one parent
        torrent_file = 'bittornado/torrent.30000K.file.torrent'
        torrent_file = 'bittornado/30000K.file.ilab1.torrent'if Socket.gethostname =~ /ilab/

	system("rm -rf '#{get_config_directory}'")

        logger = parent.logger
	logger.log "BT start download #{torrent_file}"
	download_name = './bittorrent_downloaded' + rand(1000000).to_s

        output_file = 'bittorrent_download_output' + rand(1000000).to_s
        logger.debug "writing out to #{output_file} if you'd like to tail it"
	command = "bash -c \"export TERM=vt100 && python bittornado/btdownloadheadless.py #{torrent_file} --rerequest_interval 10 --saveas #{download_name} 2>&1\""
        logger.debug "doing command #{command}"
        use_em = true
        if(use_em)
          EM::popen(command, BTWrapper) {|conn|
            conn.setup parent, download_name
          }
        else 
          start_time = Time.now
          system(command)  
          logger.log "BT output:"
          contents = File.read output_file
          logger.debug contents
          if contents =~ /SUCCESS/
	    logger.log "Bittorrent download ENDED in #{Time.now - start_time}s SUCCESS" 
          else
	    logger.log "Bittorrent download FAILED in #{Time.now - start_time}s FAILURE" 
          end
          system("rm -rf #{output_file}")
          system("rm -rf #{download_name}")
          logger.debug "resetting ~/.bittornado files"
          system("rm -rf '#{BitTorrent::get_config_directory}'")
          parent.post_BT
        end
  end

end
