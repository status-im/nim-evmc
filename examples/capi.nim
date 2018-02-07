import ../src/evmjit, examplevm, strutils


proc balance(context: ptr evm_context,
              address: ptr evm_address): evm_uint256be =
  result.bytes[0..3] = [1.uint8, 2, 3, 4]

proc address(context: ptr evm_context): evm_address =
  result.bytes[0..3] = [1.uint8, 2, 3, 4]

proc `$`(address: evm_address):string =
  result = ""
  for i in address.bytes:
    result.add($i)

proc account_exists(context: ptr evm_context, address: ptr evm_address): cint {.cdecl.}=
  echo "EVM-C: EXISTS @"
  echo address[]
  echo "\n"
  return 0

proc get_storage(result: ptr evm_uint256be,
                  context: ptr evm_context,
                  address: ptr evm_address,
                  key: ptr evm_uint256be) {.cdecl.}=
  echo "EVM-C: SLOAD @"
  echo address[]
  echo "\n"

proc set_storage(context: ptr evm_context,
                  address: ptr evm_address,
                  key: ptr evm_uint256be,
                  value: ptr evm_uint256be) {.cdecl.}=
  echo "EVM-C: SSTORE @"
  echo address[]
  echo "\n"

proc get_balance(result: ptr evm_uint256be,
                  context: ptr evm_context,
                  address: ptr evm_address) {.cdecl.}=
  echo "EVM-C: BALANCE @"
  echo address[]
  echo "\n"
  result[] = balance(context, address)

proc get_code(code: ptr ptr uint8,
              context: ptr evm_context,
              address: ptr evm_address): csize {.cdecl.}=
  echo "EVM-C: CODE @"
  echo address[]
  echo "\n"
  return 0

proc selfdestruct(context: ptr evm_context,
                  address: ptr evm_address,
                  beneficiary: ptr evm_address) {.cdecl.}=
  echo "EVM-C: SELFDESTRUCT"
  echo address[]
  echo " -> "
  echo beneficiary[]
  echo "\n"

proc call(result: ptr evm_result,
          context: ptr evm_context,
          msg: ptr evm_message) {.cdecl.}=
  echo "EVM-C: CALL (depth: %1)\n" % $msg.depth
  result.status_code = EVM_FAILURE

proc get_tx_context(result: ptr evm_tx_context, context: ptr evm_context) {.cdecl.}=
  discard

proc get_block_hash(result: ptr evm_uint256be, context: ptr evm_context, number: int64) {.cdecl.}=
  discard

# EVM log callback

# Note: the evm_log name is used to avoid conflict with `log()`C function.
proc evm_log(context: ptr evm_context,
              address: ptr evm_address,
              data: ptr uint8,
              data_size: csize,
              topics: ptr evm_uint256be,
              topics_count: csize) {.cdecl.}=
  echo "EVM-C: LOG%1\n" % $topics_count

const ctx_fn_table = evm_context_fn_table(
  account_exists: account_exists,
  get_storage: get_storage,
  set_storage: set_storage,
  get_balance: get_balance,
  get_code: get_code,
  selfdestruct: selfdestruct,
  call: call,
  get_tx_context: get_tx_context,
  get_block_hash: get_block_hash,
  emit_log: evm_log
)

# Example of how the API is supposed to be used

proc main() =
  let jit = examplevm_create()
  if jit.abi_version != EVM_ABI_VERSION:
    raise newException(LibraryError, "Incompatible ABI version")

  let
    # code: cstring = "Place some EVM bytecode here"
    code: cstring = "600160005401600055"
    code_size = code.len
    input: cstring = "Hello World!"
    gas: int64 = 200000

  var
    code_hash: evm_uint256be
    value: evm_uint256be
    address: evm_address

  code_hash.bytes[0..2] = [1.uint8, 2, 3]
  value.bytes[0..1] = [1.uint8, 0]
  address.bytes[0..2] = [1.uint8, 2, 3]

  var fn_table: ref evm_context_fn_table  # Note fn_table will be garbage collected at the end of main function
                                          # as we will always use it as ptr and not ref
  new fn_table

  fn_table[] = ctx_fn_table
  var ctx = evm_context(fn_table: cast[ptr evm_context_fn_table](fn_table))

  var msg = evm_message(
    destination: address, sender: address, value: value, input_data: cast[ptr uint8](input),
    input_size: sizeof(input), code_hash: code_hash, gas: gas, depth:0
  )

  var result = jit.execute(jit, addr ctx, EVM_HOMESTEAD, addr msg, cast[ptr uint8](code), code_size)

  echo "Execution result:\n"
  if result.status_code != EVM_SUCCESS:
    echo "  EVM execution failure: ", $result.status_code
  else:
    echo "  Gas used: ", $(gas - result.gas_left)
    echo "  Gas left: ", $result.gas_left
    echo "  Output size: ", $(gas - result.gas_left)

    echo "\n  Output: "
    var output = ""
    for i in 0 ..< result.output_size:
      output.add cast[char](cast[ptr UncheckedArray[uint8]](result.output_data)[i])
    echo output

  if not result.release.isNil:
    result.release(addr result)

  jit.destroy(jit)

main()