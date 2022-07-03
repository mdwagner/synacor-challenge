module SynacorChallenge
  module VM
    abstract def memory : Array
    abstract def registers : StaticArray
    abstract def stack : Array

    abstract def stdout : IO
    abstract def stdin : IO
    abstract def stderr : IO

    abstract def main : Nil
  end
end
