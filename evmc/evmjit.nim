when defined(windows):
  const
    libevmjit* = "libevmjit.dll"
elif defined(macosx):
  const
    libevmjit* = "libevmjit.dylib"
else:
  const
    libevmjit* = "libevmjit.so"

import evmc
export evmc

proc evmjit_create*(): ptr evmc_vm {.cdecl, importc: "evmjit_create", raises: [], gcsafe, dynlib: libevmjit.}
  ## Create EVMJIT instance.
  ##
  ## @return  The EVMJIT instance.
