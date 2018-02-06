import ../src/evmjit

# Proof of Concept of EVM-JIT bindings
# Note: libevmjit must be in path

let a = evmjit_create()

doAssert a.abi_version == 0
echo repr a

# ref 0x10735bfb8 --> [abi_version = 0,
# destroy = 0x1063214e0,
# execute = 0x106321540,
# set_option = 0x106321d00]