module X32
  class NormalChannel
    attr_reader :id
    attr_accessor :name
    attr_accessor :equalizer
    attr_accessor :bus_sends
    attr_accessor :main
    attr_accessor :dca
    attr_accessor :mute_grp
    @id ||= nil
    @name ||= nil
    @equalizer ||= nil
    @dca ||= nil
    @mute_grp ||= nil
    def initialize(parent, id)
      @parent = parent
      @id = id
      @equalizer = Hash.new
      (1..4).each do |i|
        @equalizer[i] = Hash.new
      end
      @bus_sends = Hash.new
      (1..16).each do |i|
        @bus_sends[i] = Hash.new
      end
      @main = Hash.new
      @dca = Hash.new
      @mute_grp = Hash.new
    end
  end
  class AuxChannel
  end
  class FXChannel
    attr_reader :id
    attr_accessor :name
    @id ||= nil
    @name ||= nil
    def initialize(parent, id)
      @parent = parent
      @id = id
    end
  end
  class BusChannel
  end
  class MatrixChannel
  end
  class DCAChannel
    attr_reader :id
    attr_accessor :name
    attr_accessor :unmute
    attr_accessor :level
    @id ||= nil
    @name ||= nil
    @unmute ||= nil
    @level ||= nil
    def initialize(parent, id)
      @parent = parent
      @id = id
    end
  end
  class MonoCenterChannel
  end
  class MainChannel
  end
end
