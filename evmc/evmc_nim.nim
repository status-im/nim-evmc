import evmc

type
  HostContext* = object
    host: evmc_host_interface
    context: evmc_host_context

proc getTxContext*(ctx: HostContext): evmc_tx_context =
  ctx.host.get_tx_context(ctx.context)

proc getBlockHash*(ctx: HostContext, number: int64): evmc_bytes32 =
  ctx.host.get_block_hash(ctx.context, number)

proc accountExists*(ctx: HostContext, address: evmc_address): bool =
  ctx.host.account_exists(ctx.context, address).bool

proc getStorage*(ctx: HostContext, address: evmc_address, key: evmc_bytes32): evmc_bytes32 =
  ctx.host.get_storage(ctx.context, address, key)

proc setStorage*(ctx: HostContext, address: evmc_address,
                        key, value: evmc_bytes32): evmc_storage_status =
  ctx.host.set_storage(ctx.context, address, key, value)

proc getBalance*(ctx: HostContext, address: evmc_address): evmc_uint256be =
  ctx.host.get_balance(ctx.context, address)

proc getCodeSize*(ctx: HostContext, address: evmc_address): uint =
  ctx.host.get_code_size(ctx.context, address)

proc getCodeHash*(ctx: HostContext, address: evmc_address): evmc_bytes32 =
  ctx.host.get_code_hash(ctx.context, address)

proc copyCode*(ctx: HostContext, address: evmc_address, code_offset: uint, buffer: openArray[byte]): uint =
  ctx.host.copy_code(ctx.context, address, code_offset, buffer[0].unsafeAddr, buffer.len.uint)

proc selfdestruct*(ctx: HostContext, address, beneficiary: evmc_address) =
  ctx.host.selfdestruct(ctx.context, address, beneficiary)

proc emitLog*(ctx: HostContext, address: evmc_address, data: openArray[byte], topics: openArray[evmc_bytes32]) =
  ctx.host.emit_log(ctx.context, address, data[0].unsafeAddr, data.len.uint, topics[0].unsafeAddr, topics.len.uint)

proc call*(ctx: HostContext, msg: evmc_message): evmc_result =
  ctx.host.call(ctx.context, msg)
