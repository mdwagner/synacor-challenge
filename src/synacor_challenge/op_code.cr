module SynacorChallenge
  enum OpCode : UInt16
    Halt
    Set
    Push
    Pop
    Eq
    Gt
    Jmp
    Jt
    Jf
    Add
    Mult
    Mod
    And
    Or
    Not
    Rmem
    Wmem
    Call
    Ret
    Out
    In
    Noop

    def to_u16
      self.value.to_u16
    end
  end
end
