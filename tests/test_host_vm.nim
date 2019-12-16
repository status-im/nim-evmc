import ../evmc/[evmc, evmc_nim], unittest
import evmc_nim/nim_host
import stew/byteutils

{.compile: "evmc_c/example_host.cpp".}
{.compile: "evmc_c/example_vm.cpp".}
{.passL: "-lstdc++"}

when defined(posix):
  {.passC: "-std=c++11".}

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
    input_size: input.len.uint,
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
      check EVMC_CAPABILITY_EWASM in cap

    test "setOption":
      check nvm.setOption("verbose", "2") == EVMC_SET_OPTION_SUCCESS
      check nvm.setOption("debug", "true") == EVMC_SET_OPTION_INVALID_NAME

    test "execute and destroy":
      var bn = $tx_context.block_number
      var res = nvm.execute(EVMC_HOMESTEAD, msg, code)
      check res.status_code == EVMC_SUCCESS
      check res.gas_left == 100000
      check equalMem(bn[0].addr, res.output_data, bn.len)
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
