module SynacorChallenge
  MAX_VALUE     = (2 ** 15).to_u16
  INVALID_VALUE = MAX_VALUE + 8
  REGISTERS     = MAX_VALUE...INVALID_VALUE
end
