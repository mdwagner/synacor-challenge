module SynacorChallenge
  module VM
    abstract def stdout : IO
    abstract def stdin : IO
    abstract def stderr : IO

    abstract def memory : Array
    abstract def registers : StaticArray
    abstract def stack : Array

    property pos = 0

    def run
      rewind
      while @pos < @memory.size
        yield self
      end
    end

    def rewind
      @pos = 0
      self
    end

    def current_value
      @memory[@pos]
    end
  end
end
