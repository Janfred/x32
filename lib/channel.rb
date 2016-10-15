module X32
  class NormalChannel
    attr_reader :id
    attr_accessor :name
    @id = nil
    @name = nil
    def initialize(id)
      @id = id
    end
  end
  class AuxChannel
  end
  class FXChannel
  end
  class BusChannel
  end
  class MatrixChannel
  end
  class MonoCenterChannel
  end
  class MainChannel
  end
end
