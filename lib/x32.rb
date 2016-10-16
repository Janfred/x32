require 'socket'
require 'timeout'

require 'channel.rb'

module X32
  class Mixer

    attr_reader :firmware_version, :console, :channels, :fx_channels, :dca_channels

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
      @udp_socket.send "/unsubscribe\x00\x00\x00\x00,\x00\x00\x00", 0
      # TODO unsubscribe from all subscibed channels
    end

    def send_data data
      @udp_socket.send data, 0
    end

    private

    def initialize(udp_socket, version)
      @console = version[4]
      @firmware_version = version[5]
      @channels = Hash.new
      @fx_channels = Hash.new
      @dca_channels = Hash.new
      @udp_socket = udp_socket
      preconfigure
      start_queue_worker
      get_config
    end

    def preconfigure
      (1..32).each do |i|
        @channels[i] = X32::NormalChannel.new(self, i)
      end
      (1..8).each do |i|
        @fx_channels[i] = X32::FXChannel.new(self, i)
      end
      (1..8).each do |i|
        @dca_channels[i] = X32::DCAChannel.new(self, i)
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
              elsif splitted[2].match /^\/ch\/..\/eq / then
                data = splitted[2]
                id = data[4..5].to_i
                config = data.split " "
                @channels[id].equalizer[:main] = config[1]
              elsif splitted[2].match /^\/ch\/..\/eq\// then
                data = splitted[2]
                id = data[4..5].to_i
                eq_id = data[10].to_i
                config = data.split " "
                @channels[id].equalizer[eq_id][:mode] = config[1]
                @channels[id].equalizer[eq_id][:freq] = config[2]
                @channels[id].equalizer[eq_id][:gain] = config[3]
                @channels[id].equalizer[eq_id][:q] = config[4]
              elsif splitted[2].match /^\/ch\/..\/mix / then
                data = splitted[2]
                id = data[4..5].to_i
                config = data.split " "
                @channels[id].main[:unmute] = config[1]
                @channels[id].main[:fader] = config[2]
                @channels[id].main[:lr_send] = config[3]
                @channels[id].main[:pan] = config[4]
                @channels[id].main[:mono_send] = config[5]
                @channels[id].main[:mono_level] = config[6]
              elsif splitted[2].match /^\/ch\/..\/mix\/../ then
                data = splitted[2]
                id = data[4..5].to_i
                mix_id = data[11..12].to_i
                config = data.split " "
                @channels[id].bus_sends[mix_id][:mute] = config[1]
                @channels[id].bus_sends[mix_id][:level] = config[2]
                if mix_id.odd? then
                  @channels[id].bus_sends[mix_id][:config] = config[4]
                end
              elsif splitted[2].match /^\/ch\/..\/grp/ then
                data = splitted[2]
                id = data[4..5].to_i
                config = data.split " "
                dca = config[1]
                mute_grp = config[2]
                (1..8).each do |i|
                  @channels[id].dca[i] = dca[9-i] == "1"
                end
                (1..6).each do |i|
                  @channels[id].mute_grp[i] = mute_grp[7-i] == "1"
                end
              else
                $stderr.puts "Unknown packet"
                $stderr.puts content.inspect
              end
            elsif splitted[2].match /^\/fxrtn\// then
              if splitted[2].match /^\/fxrtn\/..\/config/ then
                data = splitted[2]
                id = data[7..8].to_i
                name = data.match(/"(.*)"/)[1]
                @fx_channels[id].name = name
              elsif
                $stderr.puts "Unknown packet"
                $stderr.puts content.inspect
              end
            elsif splitted[2].match /^\/dca\// then
              if splitted[2].match /^\/dca\/. / then
                data = splitted[2]
                id = data[5].to_i
                config = data.split " "
                @dca_channels[id].unmute = config[1]
                @dca_channels[id].level = config[2]
              elsif splitted[2].match /^\/dca\/.\/config/ then
                data = splitted[2]
                id = data[5].to_i
                name = data.match(/"(.*)"/)[1]
                @dca_channels[id].name = name
              else
                $stderr.puts "Unknown projects"
                $stderr.puts content.inspect
              end
            else
              $stderr.puts "Unknown packet"
              $stderr.puts content.inspect
            end
          else
            $stderr.puts "Unknown packet"
            $stderr.puts content.inspect
          end
        rescue => e
          $stderr.puts e.class
          $stderr.puts e
          $stderr.puts e.backtrace
        end
      end
    end

    def get_config
      (1..32).each do |i|
        ch = i<10 ? "0"+i.to_s : i.to_s
        @udp_socket.send "/node\x00\x00\x00,s\x00\x00ch/#{ch}/config\x00\x00\x00\x00", 0
        @udp_socket.send "/node\x00\x00\x00,s\x00\x00ch/#{ch}/eq\x00\x00\x00\x00", 0
        (1..4).each do |e|
          @udp_socket.send "/node\x00\x00\x00,s\x00\x00ch/#{ch}/eq/#{e}\x00\x00", 0
        end
        @udp_socket.send "/node\x00\x00\x00,s\x00\x00ch/#{ch}/mix\x00\x00\x00", 0
        (1..16).each do |b|
          bus = b<10 ? "0"+b.to_s : b.to_s
          @udp_socket.send "/node\x00\x00\x00,s\x00\x00ch/#{ch}/mix/#{bus}\x00\x00\x00\x00", 0
        end
        @udp_socket.send "/node\x00\x00\x00,s\x00\x00ch/#{ch}/grp\x00\x00\x00", 0
        sleep 0.125
      end
      (1..8).each do |i|
        ch = "0" + i.to_s
        @udp_socket.send "/node\x00\x00\x00,s\x00\x00fxrtn/#{ch}/config\x00", 0
        sleep 0.125
      end
      (1..8).each do |i|
        @udp_socket.send "/node\x00\x00\x00,s\x00\x00dca/#{i}\x00\x00\x00", 0
        @udp_socket.send "/node\x00\x00\x00,s\x00\x00dca/#{i}/config\x00\x00\x00\x00", 0
        sleep 0.125
      end
    end
  end
end
