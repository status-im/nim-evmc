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

proc accountExists*(ctx: HostContext, address: evmc_address): bool =
  ctx.host.account_exists(ctx.context, address.unsafeAddr).bool

proc getStorage*(ctx: HostContext, address: evmc_address, key: evmc_bytes32): evmc_bytes32 =
  ctx.host.get_storage(ctx.context, address.unsafeAddr, key.unsafeAddr)

proc setStorage*(ctx: HostContext, address: evmc_address,
                        key, value: evmc_bytes32): evmc_storage_status =
  ctx.host.set_storage(ctx.context, address.unsafeAddr, key.unsafeAddr, value.unsafeAddr)

proc getBalance*(ctx: HostContext, address: evmc_address): evmc_uint256be =
  ctx.host.get_balance(ctx.context, address.unsafeAddr)

proc getCodeSize*(ctx: HostContext, address: evmc_address): int =
  ctx.host.get_code_size(ctx.context, address.unsafeAddr).int

proc getCodeHash*(ctx: HostContext, address: evmc_address): evmc_bytes32 =
  ctx.host.get_code_hash(ctx.context, address.unsafeAddr)

proc copyCode*(ctx: HostContext, address: evmc_address, codeOffset: int = 0): seq[byte] =
  let size = ctx.getCodeSize(address)
  if size - codeOffset > 0:
    result = newSeq[byte](size - codeOffset)
    let read = ctx.host.copy_code(ctx.context, address.unsafeAddr, code_offset.uint, result[0].addr, result.len.uint).int
    doAssert(read == result.len)

proc copyCode*(ctx: HostContext, address: evmc_address, codeOffset: int, output: ptr byte, output_len: int): int =
  ctx.host.copy_code(ctx.context, address.unsafeAddr, code_offset.uint, output, output_len.uint).int

proc selfdestruct*(ctx: HostContext, address, beneficiary: evmc_address) =
  ctx.host.selfdestruct(ctx.context, address.unsafeAddr, beneficiary.unsafeAddr)

proc emitLog*(ctx: HostContext, address: evmc_address, data: openArray[byte], topics: openArray[evmc_bytes32]) =
  ctx.host.emit_log(ctx.context, address.unsafeAddr, data[0].unsafeAddr, data.len.uint, topics[0].unsafeAddr, topics.len.uint)

proc call*(ctx: HostContext, msg: evmc_message): evmc_result =
  ctx.host.call(ctx.context, msg.unsafeAddr)

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

proc execute*(vm: EvmcVM, rev: evmc_revision, msg: evmc_message, code: openArray[byte]): evmc_result =
  vm.vm.execute(vm.vm, vm.hc.host, vm.hc.context, rev, msg, code[0].unsafeAddr, code.len.uint)

proc destroy*(vm: EvmcVM) =
  vm.vm.destroy(vm.vm)
