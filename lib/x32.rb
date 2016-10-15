require 'socket'
require 'timeout'

require 'channel.rb'

module X32
  class Mixer

    attr_reader :firmware_version, :console, :channels

    def self.connect(host)
      udp_socket = UDPSocket.new
      udp_socket.connect(host, 10023)
      udp_socket.send "/info", 0
      version = nil
      status = Timeout::timeout(10) {
        udp = udp_socket.recvfrom(10000)
        version_info = udp[0]
        version = version_info.split /\x00+/
      }

      mixer = Mixer.new(udp_socket, version)
    end

    def disconnect
      @queue_worker_thread.kill unless @queue_worker_thread.nil?
      # TODO unsubscribe from all subscibed channels
    end

    private

    def initialize(udp_socket, version)
      @console = version[4]
      @firmware_version = version[5]
      @channels = Hash.new
      @udp_socket = udp_socket
      preconfigure
      start_queue_worker
      get_config
    end

    def preconfigure
      (1..32).each do |i|
        @channels[i] = X32::NormalChannel.new(i)
      end
    end

    def start_queue_worker
      @queue_worker_thread = Thread.new { queue_worker }
    end

    def queue_worker
      loop do
        begin
          u = @udp_socket.recvfrom(10000)
          content = u[0]
          if content.match /^node/ then
            splitted = content.split /\x00+/
            if splitted[2].match /^\/ch\// then
              if splitted[2].match /^\/ch\/..\/config/ then
                data = splitted[2]
                id = data[4..5].to_i
                name = data.match(/"(.*)"/)[1]
                @channels[id].name = name
              end
            end
          end
        rescue => e
          $stderr.puts e.class
          $stderr.puts e.backtrace
        end
      end
    end

    def get_config
      (1..32).each do |i|
        @udp_socket.send "/node\x00\x00\x00,s\x00\x00ch/#{(i<10 ? "0"+i.to_s : i.to_s)}/config\x00\x00\x00\x00", 0
      end
    end
  end
end
