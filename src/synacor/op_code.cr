module Synacor
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
  end
end
