enum Synacor::OpCode : UInt16
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

  def op_name : String
    self.to_s.downcase
  end

  def op_arg_count : Int32
    case self
    in .halt?
      0
    in .set?
      2
    in .push?
      1
    in .pop?
      1
    in .eq?
      3
    in .gt?
      3
    in .jmp?
      1
    in .jt?
      2
    in .jf?
      2
    in .add?
      3
    in .mult?
      3
    in .mod?
      3
    in .and?
      3
    in .or?
      3
    in .not?
      2
    in .rmem?
      2
    in .wmem?
      2
    in .call?
      1
    in .ret?
      0
    in .out?
      1
    in .in?
      1
    in .noop?
      0
    end
  end
end
