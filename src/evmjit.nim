{.deadCodeElim: on.}
when defined(windows):
  const
    libevmjit* = "libevmjit.dll"
elif defined(macosx):
  const
    libevmjit* = "libevmjit.dylib"
else:
  const
    libevmjit* = "libevmjit.so"

import evm
export evm

proc evmjit_create*(): ptr evm_instance {.cdecl, importc: "evmjit_create", dynlib: libevmjit.}
  ## Create EVMJIT instance.
  ##
  ## @return  The EVMJIT instance.