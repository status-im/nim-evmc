# Nimbus - EVMC binary compatible interface
#
# Copyright (C) 2018-2019, 2021 Status Research & Development GmbH
# Licensed under either of
#  * Apache License, version 2.0, ([LICENSE-APACHE](LICENSE-APACHE))
#  * MIT license ([LICENSE-MIT](LICENSE-MIT))
# at your option. This file may not be copied, modified, or distributed except
# according to those terms.


import tables, hashes, strutils
import ../../evmc/evmc
import stew/byteutils

type
  Account = ref object
    balance: evmc_uint256be
    code: seq[byte]
    storage: Table[evmc_bytes32, evmc_bytes32]

  HostContext = ref object
    tx_context: evmc_tx_context
    accounts: Table[evmc_address, Account]

proc evmcHostContext(p: evmc_host_context): HostContext =
  return cast[HostContext](p)

proc hash(x: evmc_bytes32): Hash =
  result = hash(x.bytes)

proc hash(x: evmc_address): Hash =
  result = hash(x.bytes)

proc codeHash(acc: Account): evmc_bytes32 =
  # Extremely dumb "hash" function.
  for v in acc.code:
    let idx = v.int mod sizeof(result.bytes)
    result.bytes[idx] = result.bytes[idx] xor v

proc evmcReleaseResultImpl(result: var evmc_result) {.cdecl.} =
  discard

proc evmcGetTxContextImpl(p: evmc_host_context): evmc_tx_context {.cdecl.} =
  let ctx = evmcHostContext(p)
  ctx.tx_context

proc evmcGetBlockHashImpl(p: evmc_host_context, number: int64): evmc_bytes32 {.cdecl.} =
  let ctx = evmcHostContext(p)
  const hash = hexToByteArray[32]("0xb10c8a5fb10c8a5fb10c8a5fb10c8a5fb10c8a5fb10c8a5fb10c8a5fb10c8a5f")
  let current_block_number = ctx.tx_context.block_number
  if number < current_block_number and number >= current_block_number - 256:
    result.bytes = hash

proc evmcAccountExistsImpl(p: evmc_host_context, address: var evmc_address): c99bool {.cdecl.} =
  let ctx = evmcHostContext(p)
  address in ctx.accounts

proc evmcGetStorageImpl(p: evmc_host_context, address: var evmc_address, key: var evmc_bytes32): evmc_bytes32 {.cdecl.} =
  let ctx = evmcHostContext(p)
  if address in ctx.accounts:
    result = ctx.accounts[address].storage[key]

proc evmcSetStorageImpl(p: evmc_host_context, address: var evmc_address,
                        key, value: var evmc_bytes32): evmc_storage_status {.cdecl.} =
  let ctx = evmcHostContext(p)

  if address in ctx.accounts:
    var acc = ctx.accounts[address]
    let prev_value = acc.storage.getOrDefault(key)
    acc.storage[key] = value
    result = if prev_value == value: EVMC_STORAGE_UNCHANGED else: EVMC_STORAGE_MODIFIED
  else:
    var acc = Account()
    acc.storage[key] = value
    ctx.accounts[address] = acc
    result = EVMC_STORAGE_MODIFIED

proc evmcGetBalanceImpl(p: evmc_host_context, address: var evmc_address): evmc_uint256be {.cdecl.} =
  let ctx = evmcHostContext(p)
  if address in ctx.accounts:
    result = ctx.accounts[address].balance

proc evmcGetCodeSizeImpl(p: evmc_host_context, address: var evmc_address): csize_t {.cdecl.} =
  let ctx = evmcHostContext(p)
  if address in ctx.accounts:
    result = ctx.accounts[address].code.len.csize_t

proc evmcGetCodeHashImpl(p: evmc_host_context, address: var evmc_address): evmc_bytes32 {.cdecl.} =
  let ctx = evmcHostContext(p)
  if address in ctx.accounts:
    result = ctx.accounts[address].codeHash()

proc evmcCopyCodeImpl(p: evmc_host_context, address: var evmc_address,
                            code_offset: csize_t, buffer_data: ptr byte,
                            buffer_size: csize_t): csize_t {.cdecl.} =
  let ctx = evmcHostContext(p)

  if address notin ctx.accounts:
    return 0

  let acc = ctx.accounts[address]
  if code_offset.int >= acc.code.len:
    return 0

  let n = min(buffer_size.int, acc.code.len - code_offset.int)
  if n > 0:
    copyMem(buffer_data, acc.code[code_offset].addr, n)
  result = n.csize_t

proc evmcSelfdestructImpl(p: evmc_host_context, address, beneficiary: var evmc_address) {.cdecl.} =
  let ctx = evmcHostContext(p)
  discard

proc evmcEmitLogImpl(p: evmc_host_context, address: var evmc_address,
                           data: ptr byte, data_size: csize_t,
                           topics: ptr evmc_bytes32, topics_count: csize_t) {.cdecl.} =
  discard

proc evmcCallImpl(p: evmc_host_context, msg: var evmc_message): evmc_result {.cdecl.} =
  result = evmc_result(status_code: EVMC_REVERT, gas_left: msg.gas, output_data: msg.input_data, output_size: msg.input_size)

proc evmcSetOptionImpl(vm: ptr evmc_vm, name, value: cstring): evmc_set_option_result {.cdecl.} =
  let name = $name

  if name == "verbose":
    if value == nil:
      return EVMC_SET_OPTION_INVALID_VALUE
    try:
      discard parseInt($value)
      return EVMC_SET_OPTION_SUCCESS
    except:
      return EVMC_SET_OPTION_INVALID_VALUE

  return EVMC_SET_OPTION_INVALID_NAME

proc evmcExecuteImpl(vm: ptr evmc_vm, host: ptr evmc_host_interface,
                          p: evmc_host_context, rev: evmc_revision,
                          msg: evmc_message, code: ptr byte, code_size: csize_t): evmc_result {.cdecl.} =
  let ctx = evmcHostContext(p)
  var the_code = "\x43\x60\x00\x55\x43\x60\x00\x52\x59\x60\x00\xf3"
  const the_gas_used = 9 # Count the instructions, same as the C++ fake EVM.

  if (code_size.int == the_code.len) and equalMem(code, the_code[0].addr, code_size):
    let tx_context = ctx.tx_context
    let output_size = 20
    var value, key: evmc_bytes32
    value.bytes[31] = byte(tx_context.block_number)
    var dest = msg.destination
    discard p.evmcSetStorageImpl(dest, key, value)
    var output_data = alloc(output_size)
    var bn = $tx_context.block_number
    zeroMem(output_data, output_size)
    copyMem(output_data, bn[0].addr, bn.len)
    result.status_code = EVMC_SUCCESS
    result.gas_left = msg.gas - the_gas_used
    result.output_data = cast[ptr byte](output_data)
    result.output_size = output_size.csize_t
    result.release = evmcReleaseResultImpl
    return

  result.status_code = EVMC_FAILURE
  result.gas_left = 0

proc evmcGetCapabilitiesImpl(vm: ptr evmc_vm): evmc_capabilities {.cdecl.} =
  result = {EVMC_CAPABILITY_EVM1, EVMC_CAPABILITY_PRECOMPILES}

proc evmcDestroyImpl(vm: ptr evmc_vm) {.cdecl.} =
  dealloc(vm)

proc init_host_interface(): evmc_host_interface =
  # Workaround for Nim C++ codegen bug which forgets to emit the C++ cast.
  func id[T](value: T): T {.inline.} = value
  template CAST[P](value: untyped): P = cast[P](id(value))

  result.account_exists = CAST[evmc_account_exists_fn](evmcAccountExistsImpl)
  result.get_storage = CAST[evmc_get_storage_fn](evmcGetStorageImpl)
  result.set_storage = CAST[evmc_set_storage_fn](evmcSetStorageImpl)
  result.get_balance = CAST[evmc_get_balance_fn](evmcGetBalanceImpl)
  result.get_code_size = CAST[evmc_get_code_size_fn](evmcGetCodeSizeImpl)
  result.get_code_hash = CAST[evmc_get_code_hash_fn](evmcGetCodeHashImpl)
  result.copy_code = CAST[evmc_copy_code_fn](evmcCopyCodeImpl)
  result.selfdestruct = CAST[evmc_selfdestruct_fn](evmcSelfdestructImpl)
  result.call = CAST[evmc_call_fn](evmcCallImpl)
  result.get_tx_context = CAST[evmc_get_tx_context_fn](evmcGetTxContextImpl)
  result.get_block_hash = CAST[evmc_get_block_hash_fn](evmcGetBlockHashImpl)
  result.emit_log = CAST[evmc_emit_log_fn](evmcEmitLogImpl)

const
  EVMC_HOST_NAME = "example_vm"
  EVMC_VM_VERSION = "0.0.0"

proc init(vm: var evmc_vm) {.exportc, cdecl.} =
  vm.abi_version = EVMC_ABI_VERSION
  vm.name = EVMC_HOST_NAME
  vm.version = EVMC_VM_VERSION
  vm.destroy = evmcDestroyImpl

  {.emit: [vm.execute, " = (", evmc_execute_fn, ")", evmcExecuteImpl, ";" ].}
  #vm.execute = cast[evmc_execute_fn](evmcExecuteImpl)

  vm.get_capabilities = evmcGetCapabilitiesImpl
  vm.set_option = evmcSetOptionImpl

let gHost = init_host_interface()
proc nim_host_get_interface(): ptr evmc_host_interface {.exportc, cdecl.} =
  result = gHost.unsafeAddr

proc nim_host_create_context(tx_context: evmc_tx_context): HostContext {.exportc, cdecl.} =
  const address = evmc_address(bytes: hexToByteArray[20]("0x0001020000000000000000000000000000000000"))
  var acc = Account(
    balance: evmc_uint256be(bytes: hexToByteArray[32]("0x0100000000000000000000000000000000000000000000000000000000000000")),
    code: @[10.byte, 11, 12, 13, 14, 15]
  )

  result = HostContext(tx_context: tx_context)
  result.accounts[address] = acc
  GC_ref(result)

proc nim_host_destroy_context(p: evmc_host_context) {.exportc, cdecl.} =
  let ctx = evmcHostContext(p)
  GC_unref(ctx)

proc nim_create_example_vm(): ptr evmc_vm {.exportc, cdecl.} =
  result = create(evmc_vm)
  init(result[])
