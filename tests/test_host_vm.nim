# Nimbus - EVMC binary compatible interface
#
# Copyright (C) 2018-2019, 2021 Status Research & Development GmbH
# Licensed under either of
#  * Apache License, version 2.0, ([LICENSE-APACHE](LICENSE-APACHE))
#  * MIT license ([LICENSE-MIT](LICENSE-MIT))
# at your option. This file may not be copied, modified, or distributed except
# according to those terms.


import ../evmc/[evmc, evmc_nim], unittest
import evmc_nim/nim_host
import stew/byteutils

{.compile: "evmc_c/example_host.cpp".}
{.compile: "evmc_c/example_vm.cpp".}
{.passL: "-lstdc++"}

when defined(posix):
  {.passC: "-std=c++14".}

# The original EVMC C/C++ `example_host_create_context` test code wants struct
# `evmc_tx_context` passed by value, and `(tx_context: evmc_tx_context)` looks
# like it would do that.
#
# But Nim doesn't care if the type says `var` or not.  It always passes these by
# reference.  The symptoms of this mismatch look like corrupt test values, and it
# took a while to debug the real cause.
#
# Commit e2b88bb ["fixes 32 bit failure"]
# (https://github.com/status-im/nim-evmc/commit/e2b88bb) means this was known and
# thought to be a problem on 32-bit targets.  But it occurs on 64-bit x86 now too.
#
# When the argument is written as `(tx_context: var evmc_tx_context)`, Nim generates:
#     extern "C" N_CDECL(void*, example_host_create_context)(tyObject_evmc_tx_context__OA15HY3LMy1L3gcog23g9aw& tx_context);
# Called as:
#     void* T6_ = example_host_create_context(tx_contextX60gensym17426327_);
#
# But when the argument is written as `(tx_context: evmc_tx_context)`, Nim generates:
#     extern "C" N_CDECL(void*, example_host_create_context)(tyObject_evmc_tx_context__OA15HY3LMy1L3gcog23g9aw* tx_context);
# Called as:
#     void* T6_ = example_host_create_context((&tx_contextX60gensym17426326_));
#
# Either way, Nim ends up passing a pointer.  Is there a way to tell Nim to pass
# the correct value to a C function expecting a structure?  Yes, `{.bycopy.}`.
#
# Adding `...object {.bycopy.}` where `evmc_tx_context` is defined:
#     extern "C" N_CDECL(void*, example_host_create_context)(tyObject_evmc_tx_context__OA15HY3LMy1L3gcog23g9aw tx_context);
# Called as:
#     void* T6_ = example_host_create_context(tx_contextX60gensym17426330_);
#
# But there doesn't seem to be a way to add the pragma in the `proc` signature
# or a type alias, unfortunately.  It must be on the original type.  Putting it
# on the original type affects every use of the type, not just these calls, and
# we generally don't want to affect copying in other situations with a public
# API type, so adding `{.bycopy.}` is not great.
#
# So we use `var` to be certain of a reference, and modify the C/C++ to expect one.

proc example_host_get_interface(): ptr evmc_host_interface {.importc, cdecl.}
proc example_host_create_context(tx_context: var evmc_tx_context): evmc_host_context {.importc, cdecl.}
proc example_host_destroy_context(context: evmc_host_context) {.importc, cdecl.}
proc evmc_create_example_vm(): ptr evmc_vm {.importc, cdecl.}

proc nim_host_get_interface(): ptr evmc_host_interface {.importc, cdecl.}
proc nim_host_create_context(tx_context: var evmc_tx_context): evmc_host_context {.importc, cdecl.}
proc nim_host_destroy_context(context: evmc_host_context) {.importc, cdecl.}
proc nim_create_example_vm(): ptr evmc_vm {.importc, cdecl.}

template runTest(testName: string, create_vm, get_host_interface, create_host_context, destroy_host_context: untyped) =
  var vm = create_vm()
  var host = get_host_interface()
  var code = hexToSeqByte("4360005543600052596000f3")
  var input = "Hello World!"
  const gas = 200000'i64
  var address: evmc_address
  hexToByteArray("0x0001020000000000000000000000000000000000", address.bytes)
  var balance: evmc_uint256be
  hexToByteArray("0x0100000000000000000000000000000000000000000000000000000000000000", balance.bytes)
  var ahash = evmc_bytes32(bytes: [0.byte, 0, 0, 0, 0, 0, 0, 0, 0, 0, 10, 11, 12, 13, 14, 15, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0])

  var tx_context = evmc_tx_context(
    block_number: 42,
    block_timestamp: 66,
    block_gas_limit: gas * 2
  )

  var msg = evmc_message(
    kind: EVMC_CALL,
    sender: address,
    destination: address,
    value: balance,
    input_data: cast[ptr byte](input[0].addr),
    input_size: input.len.csize_t,
    gas: gas,
    depth: 0
  )

  var ctx = create_host_context(tx_context)
  var hc = HostContext.init(host, ctx)

  suite testName & ", host interface tests":
    setup:
      var
        key: evmc_bytes32
        value: evmc_bytes32

      hexToByteArray("0x0000000000000000000000000000000000000000000000000000000000000001", key.bytes)
      hexToByteArray("0x0000000000000000000000000000000000000000000000000000000000000101", value.bytes)

    test "getTxContext":
      let txc = hc.getTxContext()
      check tx_context.block_number == txc.block_number
      check tx_context.block_timestamp == txc.block_timestamp
      check tx_context.block_gas_limit == txc.block_gas_limit

    test "getBlockHash":
      var b10c: evmc_bytes32
      hexToByteArray("0xb10c8a5fb10c8a5fb10c8a5fb10c8a5fb10c8a5fb10c8a5fb10c8a5fb10c8a5f",
        b10c.bytes)
      let blockHash = hc.getBlockHash(tx_context.block_number - 1)
      check blockHash == b10c

    test "setStorage":
      check hc.setStorage(address, key, value) == EVMC_STORAGE_MODIFIED

    test "getStorage":
      let val = hc.getStorage(address, key)
      check val == value

    test "accountExists":
      check hc.accountExists(address) == true

    test "getBalance":
      let bal = hc.getBalance(address)
      check bal == balance

    test "getCodeSize":
      check hc.getCodeSize(address) == 6

    test "getCodeHash":
      let hash = hc.getCodeHash(address)
      check hash == ahash

    test "copyCode":
      let acode = @[11.byte, 12, 13, 14, 15]
      let bcode = hc.copyCode(address, 1)
      check acode == bcode

    test "selfdestruct":
      hc.selfdestruct(address, address)

    test "emitlog":
      hc.emitLog(address, code, [ahash])

    test "call":
      let res = hc.call(msg)
      check res.status_code == EVMC_REVERT
      check res.gas_left == msg.gas
      check res.output_size == msg.input_size
      check equalMem(res.output_data, msg.input_data, msg.input_size)
      # no need to release the result, it's a fake one

  suite testName & ", vm interface tests":
    setup:
      var nvm = EvmcVM.init(vm, hc)

    test "isABICompatible":
      check nvm.isABICompatible() == true

    test "vm.name":
      check nvm.name() == "example_vm"

    test "vm.version":
      check nvm.version() == "0.0.0"

    test "getCapabilities":
      let cap = nvm.getCapabilities()
      check EVMC_CAPABILITY_EVM1 in cap
      check create_vm == evmc_create_example_vm or create_vm == nim_create_example_vm
      if create_vm == evmc_create_example_vm:
        # The C++ fake VM doesn't claim to support EWASM and we won't change that.
        check EVMC_CAPABILITY_EWASM notin cap
      else:
        # But set EWASM bit in the Nim fake VM, just to verify more bits get through.
        check EVMC_CAPABILITY_EWASM in cap

    test "setOption":
      check nvm.setOption("verbose", "2") == EVMC_SET_OPTION_SUCCESS
      check nvm.setOption("debug", "true") == EVMC_SET_OPTION_INVALID_NAME

    test "execute and destroy":
      var res = nvm.execute(EVMC_HOMESTEAD, msg, code)
      check res.status_code == EVMC_SUCCESS
      check res.gas_left == 199991

      check create_vm == evmc_create_example_vm or create_vm == nim_create_example_vm
      if create_vm == evmc_create_example_vm:
        # The C++ fake VM runs the code, with this as its results.
        check res.output_size == 32
        for i in 0..<res.output_size:
          let b = cast[ptr UncheckedArray[byte]](res.output_data)[i]
          let match = if i < 31: 0x00.byte else: tx_context.block_number.byte
          check b == match
      else:
        # The Nim fake VM is not an interpreter, and just outputs this.
        check res.output_size == 20
        var bn = $tx_context.block_number
        check equalMem(bn[0].addr, res.output_data, bn.len)
        for i in bn.len..<res.output_size.int:
          let b = cast[ptr UncheckedArray[byte]](res.output_data)[i]
          check b == 0.byte
      res.release(res)

      var empty_key: evmc_bytes32
      let val = hc.getStorage(address, empty_key)
      check val.bytes[31] == tx_context.block_number.byte

      nvm.destroy()
      destroy_host_context(ctx)

proc main() =
  runTest("EVMC Nim to C API",
    evmc_create_example_vm,
    example_host_get_interface,
    example_host_create_context,
    example_host_destroy_context
  )

  runTest("EVMC Nim to Nim API",
    nim_create_example_vm,
    nim_host_get_interface,
    nim_host_create_context,
    nim_host_destroy_context
  )

main()
