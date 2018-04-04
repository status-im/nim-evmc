# Port of https://github.com/ethereum/evmjit/blob/develop/examples/examplevm.c
# to Nim language

import ../src/evmjit, strutils

proc c_malloc(size: csize): pointer {.
  importc: "malloc", header: "<stdlib.h>".}
proc c_calloc(num, size: csize): pointer {.
  importc: "calloc", header: "<stdlib.h>".}
proc c_free(p: pointer) {.
  importc: "free", header: "<stdlib.h>".}


type ExampleVM = object
  instance: evmc_instance
  verbose: bool

proc evmc_destroy(evm: ptr evmc_instance) {.cdecl.}=
  c_free evm

# Example options

proc evmc_set_option(instance: ptr evmc_instance, name: cstring, value: cstring): cint {.cdecl.}=
  var vm = ExampleVM(instance: instance[])
  if name == "verbose":
    vm.verbose = ($name).parseBool
    # Note: we don't return 1 if not a number or in int range as Nim will throw an exception instead
  return 0

proc evmc_release_result(r: ptr evmc_result) {.cdecl.}=
  r[] = evmc_result() # Create a new empty evmc_result

proc free_result_output_data(r: ptr evmc_result) {.cdecl.}=
  c_free r.output_data

proc execute(instance: ptr evmc_instance; context: ptr evmc_context;
            rev: evmc_revision; msg: ptr evmc_message; code: ptr uint8;
            code_size: csize): evmc_result {.cdecl.}=
  if code_size == 0:
    # In case of empty code return a fancy error message
    let error: cstring =  if rev == EVM_BYZANTIUM: "Welcome to Byzantium"
                          else: "Hello Ethereum"
    result.output_data = cast[ptr uint8](error)
    result.output_size = error.len
    result.status_code = EVM_FAILURE
    result.release = nil # We don't need to release the constant messages
    return

  let vm: ptr ExampleVM = cast[ptr ExampleVM](instance) # So much hacks in original code :/

  # Simulate executing by checking for some code patterns.
  # Solidity inline assemble is used in the examples instead of EVM bytecode.

  # Assembly: `{ mstore(0, address()) return(0, msize()) }`.
  const return_address = "30600052596000f3"

  # Assembly: `{ sstore(0, add(sload(0), 1)) }`
  const counter = "600160005401600055"

  echo "Debug: code_size = ", $code_size
  echo "Debug: return_address.len = ", $return_address.len
  echo "Debug: counter.len = ", $counter.len
  echo "Debug: $cast[cstring](code) == return_address - ", $($cast[cstring](code) == return_address)
  echo "Debug: $cast[cstring](code) == counter - ", $($cast[cstring](code) == counter)
  echo "\n"

  if code_size == return_address.len and $cast[cstring](code) == return_address:
    let address_size = sizeof(msg.destination)
    var output_data = cast[ptr uint8](c_malloc(address_size))
    if output_data == nil:
      result.status_code = EVM_INTERNAL_ERROR
      return

    copyMem(output_data, addr msg.destination, address_size)
    result.status_code = EVM_SUCCESS
    result.output_data = output_data
    result.output_size = address_size
    result.release = free_result_output_data
    return

  elif code_size == counter.len and $cast[cstring](code) == counter:
    var value: evmc_uint256be
    var index = evmc_uint256be() # Need var to have an address. Initialized to all 0 by default
    context.fn_table.get_storage(addr value, context, addr msg.destination, addr index)
    value.bytes[31] += 1
    context.fn_table.set_storage(context, addr msg.destination, addr index, addr value)
    result.status_code = EVM_SUCCESS
    return

  result.release = evmc_release_result
  result.status_code = EVM_FAILURE
  result.gas_left = 0

  if vm.verbose:
    echo "Execution done.\n"


proc examplevm_create*(): ptr evmc_instance =
  var init = evmc_instance(
    abi_version: EVM_ABI_VERSION,
    destroy: evmc_destroy,
    execute: execute,
    set_option: evmc_set_option
  )
  let vm = cast[ptr ExampleVM](c_calloc(1, sizeof(ExampleVM)))
  result = addr vm.instance
  copyMem(result, addr init, sizeof(init))
