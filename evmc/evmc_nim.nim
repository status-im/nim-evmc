# Nimbus - EVMC binary compatible interface
#
# Copyright (C) 2018-2019, 2021 Status Research & Development GmbH
# Licensed under either of
#  * Apache License, version 2.0, ([LICENSE-APACHE](LICENSE-APACHE))
#  * MIT license ([LICENSE-MIT](LICENSE-MIT))
# at your option. This file may not be copied, modified, or distributed except
# according to those terms.


import evmc

type
  HostContext* = object
    host: ptr evmc_host_interface
    context: evmc_host_context

  EvmcVM* = object
    vm: ptr evmc_vm
    hc: HostContext

proc init*(x: var HostContext, host: ptr evmc_host_interface, context: evmc_host_context) =
  x.host = host
  x.context = context

proc init*(x: typedesc[HostContext], host: ptr evmc_host_interface, context: evmc_host_context): HostContext =
  result.init(host, context)

proc getTxContext*(ctx: HostContext): evmc_tx_context =
  ctx.host.get_tx_context(ctx.context)

proc getBlockHash*(ctx: HostContext, number: int64): evmc_bytes32 =
  ctx.host.get_block_hash(ctx.context, number)

proc accountExists*(ctx: HostContext, address: var evmc_address): bool =
  ctx.host.account_exists(ctx.context, address).bool

proc getStorage*(ctx: HostContext, address: var evmc_address, key: var evmc_bytes32): evmc_bytes32 =
  ctx.host.get_storage(ctx.context, address, key)

proc setStorage*(ctx: HostContext, address: var evmc_address,
                        key, value: var evmc_bytes32): evmc_storage_status =
  ctx.host.set_storage(ctx.context, address, key, value)

proc getBalance*(ctx: HostContext, address: var evmc_address): evmc_uint256be =
  ctx.host.get_balance(ctx.context, address)

proc getCodeSize*(ctx: HostContext, address: var evmc_address): int =
  ctx.host.get_code_size(ctx.context, address).int

proc getCodeHash*(ctx: HostContext, address: var evmc_address): evmc_bytes32 =
  ctx.host.get_code_hash(ctx.context, address)

proc copyCode*(ctx: HostContext, address: var evmc_address, codeOffset: int = 0): seq[byte] =
  let size = ctx.getCodeSize(address)
  if size - codeOffset > 0:
    result = newSeq[byte](size - codeOffset)
    let read = ctx.host.copy_code(ctx.context, address, code_offset.csize_t, result[0].addr, result.len.csize_t).int
    doAssert(read == result.len)

proc copyCode*(ctx: HostContext, address: var evmc_address, codeOffset: int, output: ptr byte, output_len: int): int =
  ctx.host.copy_code(ctx.context, address, code_offset.csize_t, output, output_len.csize_t).int

proc selfdestruct*(ctx: HostContext, address, beneficiary: var evmc_address) =
  ctx.host.selfdestruct(ctx.context, address, beneficiary)

proc emitLog*(ctx: HostContext, address: var evmc_address, data: openArray[byte], topics: openArray[evmc_bytes32]) =
  ctx.host.emit_log(ctx.context, address, data[0].unsafeAddr, data.len.csize_t, topics[0].unsafeAddr, topics.len.csize_t)

proc accessAccount*(ctx: HostContext, address: var evmc_address): evmc_access_status =
  ctx.host.access_account(ctx.context, address)

proc accessStorage*(ctx: HostContext, address: var evmc_address, key: var evmc_bytes32): evmc_access_status =
  ctx.host.access_storage(ctx.context, address, key)

proc call*(ctx: HostContext, msg: var evmc_message): evmc_result =
  ctx.host.call(ctx.context, msg)

proc init*(x: var EvmcVM, vm: ptr evmc_vm, hc: HostContext) =
  x.vm = vm
  x.hc = hc

proc init*(x: typedesc[EvmcVM], vm: ptr evmc_vm, hc: HostContext): EvmcVM =
  result.init(vm, hc)

proc init*(x: typedesc[EvmcVM], vm: ptr evmc_vm): EvmcVM =
  result.init(vm, HostContext())

proc isABICompatible*(vm: EvmcVM): bool =
  vm.vm.abi_version == EVMC_ABI_VERSION

proc name*(vm: EvmcVM): string =
  $vm.vm.name

proc version*(vm: EvmcVM): string =
  $vm.vm.version

proc getCapabilities*(vm: EvmcVM): evmc_capabilities =
  vm.vm.get_capabilities(vm.vm)

proc setOption*(vm: EvmcVM, name, value: string): evmc_set_option_result =
  if not vm.vm.set_option.isNil:
    return vm.vm.set_option(vm.vm, name, value)

  result = EVMC_SET_OPTION_INVALID_NAME

proc execute*(vm: EvmcVM, rev: evmc_revision, msg: var evmc_message, code: openArray[byte]): evmc_result =
  vm.vm.execute(vm.vm, vm.hc.host, vm.hc.context, rev, msg, code[0].unsafeAddr, code.len.csize_t)

proc destroy*(vm: EvmcVM) =
  vm.vm.destroy(vm.vm)

proc destroy*(res: var evmc_result) =
  if not res.release.isNil:
    res.release(res)
