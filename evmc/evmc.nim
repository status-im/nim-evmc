# Nimbus
# Copyright (c) 2019 Status Research & Development GmbH
# Licensed under either of
#  * Apache License, version 2.0, ([LICENSE-APACHE](LICENSE-APACHE))
#  * MIT license ([LICENSE-MIT](LICENSE-MIT))
# at your option.
# This file may not be copied, modified, or distributed except according to
# those terms.


# The EVMC ABI version number of the interface declared in this file.
#
# The EVMC ABI version always equals the major version number of the EVMC project.
# The Host SHOULD check if the ABI versions match when dynamically loading VMs.
const
  EVMC_ABI_VERSION* = 7.cint

type
  # SPECIAL NOTE
  # EVMC adopt C99 standard, and one of it's interface using
  # C99 'bool' as return type. Nowhere in the C documentation
  # mentions about it's size.
  # chfast@ethereum/evmc told me about this "https://godbolt.org/z/marD9R"
  # lucky for us, in practice C compilers agree to use one byte long for C99 bool.
  # Nim sizeof(bool) also == 1.
  # but still we need to be careful about this though.
  c99bool* = bool

  # The fixed size array of 32 bytes.
  # 32 bytes of data capable of storing e.g. 256-bit hashes.
  evmc_bytes32* = object
    bytes*: array[32, byte]

  # The alias for evmc_bytes32 to represent a big-endian 256-bit integer.
  evmc_uint256be* = evmc_bytes32

  # Big-endian 160-bit hash suitable for keeping an Ethereum address.
  evmc_address* = object
    bytes*: array[20, byte]

  # The kind of call-like instruction.
  evmc_call_kind* {.size: sizeof(cint).} = enum
    EVMC_CALL = 0         # Request CALL.
    EVMC_DELEGATECALL = 1 # Request DELEGATECALL. Valid since Homestead.
                          #  The value param ignored.
    EVMC_CALLCODE = 2     # Request CALLCODE.
    EVMC_CREATE = 3       # Request CREATE.
    EVMC_CREATE2 = 4      # Request CREATE2. Valid since Constantinople.

  # The flags for ::evmc_message.
  evmc_flags* {.size: sizeof(cint).} = enum
    EVMC_STATIC = 1  # Static call mode.

  # The message describing an EVM call,
  # including a zero-depth calls from a transaction origin.
  evmc_message* = object
    # The kind of the call. For zero-depth calls ::EVMC_CALL SHOULD be used.
    kind*: evmc_call_kind

    # Additional flags modifying the call execution behavior.
    # In the current version the only valid values are ::EVMC_STATIC or 0.
    flags*: uint32

    # The call depth.
    depth*: int32

    # The amount of gas for message execution.
    gas*: int64

    # The destination of the message.
    destination*: evmc_address

    # The sender of the message.
    sender*: evmc_address

    # The message input data.
    # This MAY be NULL.
    input_data*: ptr byte

    # The size of the message input data.
    # If input_data is NULL this MUST be 0.
    # actually it's a size_t
    input_size*: uint

    # The amount of Ether transferred with the message.
    value*: evmc_uint256be

    # The optional value used in new contract address construction.
    # Ignored unless kind is EVMC_CREATE2.
    create2_salt*: evmc_bytes32

  # The transaction and block data for execution.
  evmc_tx_context* = object
    tx_gas_price*    : evmc_uint256be # The transaction gas price.
    tx_origin*       : evmc_address   # The transaction origin account.
    block_coinbase*  : evmc_address   # The miner of the block.
    block_number*    : int64          # The block number.
    block_timestamp* : int64          # The block timestamp.
    block_gas_limit* : int64          # The block gas limit.
    block_difficulty*: evmc_uint256be # The block difficulty.
    chain_id*        : evmc_uint256be # The blockchain's ChainID.

  # @struct evmc_host_context
  # The opaque data type representing the Host execution context.
  # @see evmc_execute_fn().
  evmc_host_context* = distinct pointer

  # Get transaction context callback function.
  #
  # This callback function is used by an EVM to retrieve the transaction and
  # block context.
  #
  # @param      context  The pointer to the Host execution context.
  # @return              The transaction context.
  evmc_get_tx_context_fn* = proc(context: evmc_host_context): evmc_tx_context {.cdecl.}

  # Get block hash callback function.
  #
  # This callback function is used by a VM to query the hash of the header of the given block.
  # If the information about the requested block is not available, then this is signalled by
  # returning null bytes.
  #
  # @param context  The pointer to the Host execution context.
  # @param number   The block number.
  # @return         The block hash or null bytes
  #                 if the information about the block is not available.
  evmc_get_block_hash_fn* = proc(context: evmc_host_context, number: int64): evmc_bytes32 {.cdecl.}

  # The execution status code.
  #
  # Successful execution is represented by ::EVMC_SUCCESS having value 0.
  #
  # Positive values represent failures defined by VM specifications with generic
  # ::EVMC_FAILURE code of value 1.
  #
  # Status codes with negative values represent VM internal errors
  # not provided by EVM specifications. These errors MUST not be passed back
  # to the caller. They MAY be handled by the Client in predefined manner
  # (see e.g. ::EVMC_REJECTED), otherwise internal errors are not recoverable.
  # The generic representant of errors is ::EVMC_INTERNAL_ERROR but
  # an EVM implementation MAY return negative status codes that are not defined
  # in the EVMC documentation.
  #
  # @note
  # In case new status codes are needed, please create an issue or pull request
  # in the EVMC repository (https://github.com/ethereum/evmc).
  evmc_status_code* = distinct cint
    # EVMC_SUCCESS
    # EVMC_FAILURE
    # EVMC_REVERT
    # EVMC_OUT_OF_GAS
    # EVMC_INVALID_INSTRUCTION
    # EVMC_UNDEFINED_INSTRUCTION
    # EVMC_STACK_OVERFLOW
    # EVMC_STACK_UNDERFLOW
    # EVMC_BAD_JUMP_DESTINATION
    # EVMC_INVALID_MEMORY_ACCESS
    # EVMC_CALL_DEPTH_EXCEEDED
    # EVMC_STATIC_MODE_VIOLATION
    # EVMC_PRECOMPILE_FAILURE
    # EVMC_CONTRACT_VALIDATION_FAILURE
    # EVMC_ARGUMENT_OUT_OF_RANGE
    # EVMC_WASM_UNREACHABLE_INSTRUCTION
    # EVMC_WASM_TRAP
    # EVMC_INTERNAL_ERROR
    # EVMC_REJECTED
    # EVMC_OUT_OF_MEMORY

  # Releases resources assigned to an execution result.
  #
  # This function releases memory (and other resources, if any) assigned to the
  # specified execution result making the result object invalid.
  #
  # @param result  The execution result which resources are to be released. The
  #                result itself it not modified by this function, but becomes
  #                invalid and user MUST discard it as well.
  #                This MUST NOT be NULL.
  #
  # @note
  # The result is passed by pointer to avoid (shallow) copy of the ::evmc_result
  # struct. Think of this as the best possible C language approximation to
  # passing objects by reference.
  evmc_release_result_fn* = proc(result: var evmc_result) {.cdecl.}

  # The EVM code execution result.
  evmc_result* = object
    # The execution status code.
    status_code*: evmc_status_code

    #The amount of gas left after the execution.
    # If evmc_result::code is not ::EVMC_SUCCESS nor ::EVMC_REVERT
    # the value MUST be 0.
    gas_left*: int64

    # The reference to output data.
    #
    #  The output contains data coming from RETURN opcode (iff evmc_result::code
    #  field is ::EVMC_SUCCESS) or from REVERT opcode.
    #
    #  The memory containing the output data is owned by EVM and has to be
    #  freed with evmc_result::release().
    #
    #  This MAY be NULL.
    output_data*: ptr byte

    # The size of the output data.
    #  If output_data is NULL this MUST be 0.
    output_size*: uint

    # The method releasing all resources associated with the result object.
    #
    # This method (function pointer) is optional (MAY be NULL) and MAY be set
    # by the VM implementation. If set it MUST be called by the user once to
    # release memory and other resources associated with the result object.
    # Once the resources are released the result object MUST NOT be used again.
    #
    # The suggested code pattern for releasing execution results:
    # @code
    # struct evmc_result result = ...;
    # if (result.release)
    #     result.release(&result);
    # @endcode
    #
    # @note
    # It works similarly to C++ virtual destructor. Attaching the release
    # function to the result itself allows VM composition.
    release*: evmc_release_result_fn

    # The address of the contract created by create instructions.
    #
    # This field has valid value only if:
    # - it is a result of the Host method evmc_host_interface::call
    # - and the result describes successful contract creation
    #   (evmc_result::status_code is ::EVMC_SUCCESS).
    # In all other cases the address MUST be null bytes.
    #
    create_address*: evmc_address

    # Reserved data that MAY be used by a evmc_result object creator.
    #
    #  This reserved 4 bytes together with 20 bytes from create_address form
    #  24 bytes of memory called "optional data" within evmc_result struct
    #  to be optionally used by the evmc_result object creator.
    #
    #  @see evmc_result_optional_data, evmc_get_optional_data().
    #
    #  Also extends the size of the evmc_result to 64 bytes (full cache line).
    padding*: array[4, byte]

  # Check account existence callback function.
  #
  # This callback function is used by the VM to check if
  # there exists an account at given address.
  # @param context  The pointer to the Host execution context.
  # @param address  The address of the account the query is about.
  # @return         true if exists, false otherwise.
  evmc_account_exists_fn* = proc(context: evmc_host_context, address: ptr evmc_address): c99bool {.cdecl.}

  #  Get storage callback function.
  #
  #  This callback function is used by a VM to query the given account storage entry.
  #
  #  @param context  The Host execution context.
  #  @param address  The address of the account.
  #  @param key      The index of the account's storage entry.
  #  @return         The storage value at the given storage key or null bytes
  #                  if the account does not exist.
  evmc_get_storage_fn* = proc(context: evmc_host_context, address: ptr evmc_address, key: ptr evmc_bytes32): evmc_bytes32 {.cdecl.}

  # The effect of an attempt to modify a contract storage item.
  #
  # For the purpose of explaining the meaning of each element, the following
  # notation is used:
  # - 0 is zero value,
  # - X != 0 (X is any value other than 0),
  # - Y != X, Y != 0 (Y is any value other than X and 0),
  # - Z != Y (Z is any value other than Y),
  # - the "->" means the change from one value to another.
  evmc_storage_status* {.size: sizeof(cint).} = enum
    # The value of a storage item has been left unchanged: 0 -> 0 and X -> X.
    EVMC_STORAGE_UNCHANGED = 0

    # The value of a storage item has been modified: X -> Y.
    EVMC_STORAGE_MODIFIED = 1

    # A storage item has been modified after being modified before: X -> Y -> Z.
    EVMC_STORAGE_MODIFIED_AGAIN = 2

    # A new storage item has been added: 0 -> X.
    EVMC_STORAGE_ADDED = 3

    # A storage item has been deleted: X -> 0.
    EVMC_STORAGE_DELETED = 4

  # Set storage callback function.
  #
  # This callback function is used by a VM to update the given account storage entry.
  # The VM MUST make sure that the account exists. This requirement is only a formality because
  # VM implementations only modify storage of the account of the current execution context
  # (i.e. referenced by evmc_message::destination).
  #
  # @param context  The pointer to the Host execution context.
  # @param address  The address of the account.
  # @param key      The index of the storage entry.
  # @param value    The value to be stored.
  # @return         The effect on the storage item.
  evmc_set_storage_fn* = proc(context: evmc_host_context, address: ptr evmc_address,
                              key, value: ptr evmc_bytes32): evmc_storage_status {.cdecl.}

  # Get balance callback function.
  #
  # This callback function is used by a VM to query the balance of the given account.
  #
  # @param context  The pointer to the Host execution context.
  # @param address  The address of the account.
  # @return         The balance of the given account or 0 if the account does not exist.
  evmc_get_balance_fn* = proc(context: evmc_host_context, address: ptr evmc_address): evmc_uint256be {.cdecl.}

  # Get code size callback function.
  #
  # This callback function is used by a VM to get the size of the code stored
  # in the account at the given address.
  #
  # @param context  The pointer to the Host execution context.
  # @param address  The address of the account.
  # @return         The size of the code in the account or 0 if the account does not exist.
  evmc_get_code_size_fn* = proc(context: evmc_host_context, address: ptr evmc_address): uint {.cdecl.}

  # Get code hash callback function.
  #
  # This callback function is used by a VM to get the keccak256 hash of the code stored
  # in the account at the given address. For existing accounts not having a code, this
  # function returns keccak256 hash of empty data.
  #
  # @param context  The pointer to the Host execution context.
  # @param address  The address of the account.
  # @return         The hash of the code in the account or null bytes if the account does not exist.
  evmc_get_code_hash_fn* = proc(context: evmc_host_context, address: ptr evmc_address): evmc_bytes32 {.cdecl.}

  # Copy code callback function.
  #
  # This callback function is used by an EVM to request a copy of the code
  # of the given account to the memory buffer provided by the EVM.
  # The Client MUST copy the requested code, starting with the given offset,
  # to the provided memory buffer up to the size of the buffer or the size of
  # the code, whichever is smaller.
  #
  # @param context      The pointer to the Host execution context. See ::evmc_host_context.
  # @param address      The address of the account.
  # @param code_offset  The offset of the code to copy.
  # @param buffer_data  The pointer to the memory buffer allocated by the EVM
  #                     to store a copy of the requested code.
  # @param buffer_size  The size of the memory buffer.
  # @return             The number of bytes copied to the buffer by the Client.
  evmc_copy_code_fn* = proc(context: evmc_host_context, address: ptr evmc_address,
                            code_offset: uint, buffer_data: ptr byte,
                            buffer_size: uint): uint {.cdecl.}

  # Selfdestruct callback function.
  #
  # This callback function is used by an EVM to SELFDESTRUCT given contract.
  # The execution of the contract will not be stopped, that is up to the EVM.
  #
  # @param context      The pointer to the Host execution context. See ::evmc_host_context.
  # @param address      The address of the contract to be selfdestructed.
  # @param beneficiary  The address where the remaining ETH is going to be transferred.
  evmc_selfdestruct_fn* = proc(context: evmc_host_context, address, beneficiary: ptr evmc_address) {.cdecl.}

  # Log callback function.
  #
  # This callback function is used by an EVM to inform about a LOG that happened
  # during an EVM bytecode execution.
  #
  # @param context       The pointer to the Host execution context. See ::evmc_host_context.
  # @param address       The address of the contract that generated the log.
  # @param data          The pointer to unindexed data attached to the log.
  # @param data_size     The length of the data.
  # @param topics        The pointer to the array of topics attached to the log.
  # @param topics_count  The number of the topics. Valid values are between 0 and 4 inclusively.
  evmc_emit_log_fn* = proc(context: evmc_host_context, address: ptr evmc_address,
                           data: ptr byte, data_size: uint,
                           topics: ptr evmc_bytes32, topics_count: uint) {.cdecl.}

  # Pointer to the callback function supporting EVM calls.
  #
  # @param context  The pointer to the Host execution context.
  # @param msg      The call parameters.
  # @return         The result of the call.
  evmc_call_fn* = proc(context: evmc_host_context, msg: ptr evmc_message): evmc_result {.cdecl.}

  # The Host interface.
  #
  # The set of all callback functions expected by VM instances. This is C
  # realisation of vtable for OOP interface (only virtual methods, no data).
  # Host implementations SHOULD create constant singletons of this (similarly
  # to vtables) to lower the maintenance and memory management cost.
  evmc_host_interface* = object
    # Check account existence callback function.
    account_exists*: evmc_account_exists_fn

    # Get storage callback function.
    get_storage*: evmc_get_storage_fn

    # Set storage callback function.
    set_storage*: evmc_set_storage_fn

    # Get balance callback function.
    get_balance*: evmc_get_balance_fn

    # Get code size callback function.
    get_code_size*: evmc_get_code_size_fn

    # Get code hash callback function.
    get_code_hash*: evmc_get_code_hash_fn

    # Copy code callback function.
    copy_code*: evmc_copy_code_fn

    # Selfdestruct callback function.
    selfdestruct*: evmc_selfdestruct_fn

    # Call callback function.
    call*: evmc_call_fn

    # Get transaction context callback function.
    get_tx_context*: evmc_get_tx_context_fn

    # Get block hash callback function.
    get_block_hash*: evmc_get_block_hash_fn

    # Emit log callback function.
    emit_log*: evmc_emit_log_fn

  # Destroys the VM instance.
  #
  # @param vm  The VM instance to be destroyed.
  evmc_destroy_fn* = proc(vm: ptr evmc_vm) {.cdecl.}

  # Possible outcomes of evmc_set_option.
  evmc_set_option_result* {.size: sizeof(cint).} = enum
    EVMC_SET_OPTION_SUCCESS = 0
    EVMC_SET_OPTION_INVALID_NAME = 1
    EVMC_SET_OPTION_INVALID_VALUE = 2

  # Configures the VM instance.
  #
  # Allows modifying options of the VM instance.
  # Options:
  # - code cache behavior: on, off, read-only, ...
  # - optimizations,
  #
  # @param vm     The VM instance to be configured.
  # @param name   The option name. NULL-terminated string. Cannot be NULL.
  # @param value  The new option value. NULL-terminated string. Cannot be NULL.
  # @return       The outcome of the operation.
  evmc_set_option_fn* = proc(vm: ptr evmc_vm, name, value: cstring): evmc_set_option_result {.cdecl.}

  # EVM revision.
  #
  # The revision of the EVM specification based on the Ethereum
  # upgrade / hard fork codenames.
  evmc_revision* {.size: sizeof(cint).} = enum
    # The Frontier revision.
    # The one Ethereum launched with.
    EVMC_FRONTIER = 0

    # The Homestead revision.
    # https://eips.ethereum.org/EIPS/eip-606
    EVMC_HOMESTEAD = 1

    # The Tangerine Whistle revision.
    # https://eips.ethereum.org/EIPS/eip-608
    EVMC_TANGERINE_WHISTLE = 2

    # The Spurious Dragon revision.
    # https://eips.ethereum.org/EIPS/eip-607
    EVMC_SPURIOUS_DRAGON = 3

    # The Byzantium revision.
    # https://eips.ethereum.org/EIPS/eip-609
    EVMC_BYZANTIUM = 4

    # The Constantinople revision.
    # https://eips.ethereum.org/EIPS/eip-1013
    EVMC_CONSTANTINOPLE = 5

    # The Petersburg revision.
    # Other names: Constantinople2, ConstantinopleFix.
    # https://eips.ethereum.org/EIPS/eip-1716
    EVMC_PETERSBURG = 6

    # The Istanbul revision.
    # The spec draft: https://eips.ethereum.org/EIPS/eip-1679.
    EVMC_ISTANBUL = 7

    # The Berlin revision.
    # The spec draft: https://eips.ethereum.org/EIPS/eip-2070.
    EVMC_BERLIN = 8

  # Executes the given code using the input from the message.
  #
  # This function MAY be invoked multiple times for a single VM instance.
  #
  # @param vm         The VM instance. This argument MUST NOT be NULL.
  # @param host       The Host interface. This argument MUST NOT be NULL unless
  #                   the @p vm has the ::EVMC_CAPABILITY_PRECOMPILES capability.
  # @param context    The opaque pointer to the Host execution context.
  #                   This argument MAY be NULL. The VM MUST pass the same
  #                   pointer to the methods of the @p host interface.
  #                   The VM MUST NOT dereference the pointer.
  # @param rev        The requested EVM specification revision.
  # @param msg        The call parameters. See ::evmc_message. This argument MUST NOT be NULL.
  # @param code       The reference to the code to be executed. This argument MAY be NULL.
  # @param code_size  The length of the code. If @p code is NULL this argument MUST be 0.
  # @return           The execution result.
  evmc_execute_fn* = proc(vm: ptr evmc_vm, host: ptr evmc_host_interface,
                          context: evmc_host_context, rev: evmc_revision,
                          msg: evmc_message, code: ptr byte, code_size: uint): evmc_result {.cdecl.}

  # Possible capabilities of a VM.
  evmc_capabilities* = distinct uint32
    # EVMC_CAPABILITY_EVM1
    # EVMC_CAPABILITY_EWASM
    # EVMC_CAPABILITY_PRECOMPILES

  # Return the supported capabilities of the VM instance.
  #
  # This function MAY be invoked multiple times for a single VM instance,
  # and its value MAY be influenced by calls to evmc_vm::set_option.
  #
  # @param vm  The VM instance.
  # @return    The supported capabilities of the VM. @see evmc_capabilities.
  evmc_get_capabilities_fn* = proc(vm: ptr evmc_vm): evmc_capabilities {.cdecl.}

  # The VM instance.
  #
  # Defines the base struct of the VM implementation.
  evmc_vm* = object
    # EVMC ABI version implemented by the VM instance.
    #
    # Can be used to detect ABI incompatibilities.
    # The EVMC ABI version represented by this file is in ::EVMC_ABI_VERSION.
    abi_version*: cint

    # The name of the EVMC VM implementation.
    #
    # It MUST be a NULL-terminated not empty string.
    # The content MUST be UTF-8 encoded (this implies ASCII encoding is also allowed).
    name*: cstring

    # The version of the EVMC VM implementation, e.g. "1.2.3b4".
    #
    # It MUST be a NULL-terminated not empty string.
    # The content MUST be UTF-8 encoded (this implies ASCII encoding is also allowed).
    version*: cstring

    # Pointer to function destroying the VM instance.
    #
    # This is a mandatory method and MUST NOT be set to NULL.
    destroy*: evmc_destroy_fn

    # Pointer to function executing a code by the VM instance.
    #
    # This is a mandatory method and MUST NOT be set to NULL.
    execute*: evmc_execute_fn

    # A method returning capabilities supported by the VM instance.
    #
    # The value returned MAY change when different options are set via the set_option() method.
    #
    # A Client SHOULD only rely on the value returned if it has queried it after
    # it has called the set_option().
    #
    # This is a mandatory method and MUST NOT be set to NULL.
    get_capabilities*: evmc_get_capabilities_fn

    # Optional pointer to function modifying VM's options.
    #
    #  If the VM does not support this feature the pointer can be NULL.
    set_option*: evmc_set_option_fn

const
  # The VM is capable of executing EVM1 bytecode.
  EVMC_CAPABILITY_EVM1* = 1.evmc_capabilities

  # The VM is capable of executing ewasm bytecode.
  EVMC_CAPABILITY_EWASM* = 2.evmc_capabilities

  # The VM is capable of executing the precompiled contracts
  # defined for the range of destination addresses.
  #
  # The EIP-1352 (https://eips.ethereum.org/EIPS/eip-1352) specifies
  # the range 0x000...0000 - 0x000...ffff of addresses
  # reserved for precompiled and system contracts.
  #
  # This capability is **experimental** and MAY be removed without notice.
  EVMC_CAPABILITY_PRECOMPILES* = 4.evmc_capabilities

  # Execution finished with success.
  EVMC_SUCCESS* = 0.evmc_status_code

  # Generic execution failure.
  EVMC_FAILURE* = 1.evmc_status_code

  # Execution terminated with REVERT opcode.
  #
  # In this case the amount of gas left MAY be non-zero and additional output
  # data MAY be provided in ::evmc_result.
  EVMC_REVERT* = 2.evmc_status_code

  # The execution has run out of gas.
  EVMC_OUT_OF_GAS* = 3.evmc_status_code

  # The designated INVALID instruction has been hit during execution.
  #
  # The EIP-141 (https://github.com/ethereum/EIPs/blob/master/EIPS/eip-141.md)
  # defines the instruction 0xfe as INVALID instruction to indicate execution
  # abortion coming from high-level languages. This status code is reported
  # in case this INVALID instruction has been encountered.
  EVMC_INVALID_INSTRUCTION* = 4.evmc_status_code

  # An undefined instruction has been encountered.
  EVMC_UNDEFINED_INSTRUCTION* = 5.evmc_status_code

  # The execution has attempted to put more items on the EVM stack
  # than the specified limit.
  EVMC_STACK_OVERFLOW* = 6.evmc_status_code

  # Execution of an opcode has required more items on the EVM stack.
  EVMC_STACK_UNDERFLOW* = 7.evmc_status_code

  # Execution has violated the jump destination restrictions.
  EVMC_BAD_JUMP_DESTINATION* = 8.evmc_status_code

  # Tried to read outside memory bounds.
  #
  # An example is RETURNDATACOPY reading past the available buffer.
  EVMC_INVALID_MEMORY_ACCESS* = 9.evmc_status_code

  # Call depth has exceeded the limit (if any)
  EVMC_CALL_DEPTH_EXCEEDED* = 10.evmc_status_code

  # Tried to execute an operation which is restricted in static mode.
  EVMC_STATIC_MODE_VIOLATION* = 11.evmc_status_code

  # A call to a precompiled or system contract has ended with a failure.
  #
  # An example: elliptic curve functions handed invalid EC points.
  EVMC_PRECOMPILE_FAILURE* = 12.evmc_status_code

  # Contract validation has failed (e.g. due to EVM 1.5 jump validity,
  # Casper's purity checker or ewasm contract rules).
  EVMC_CONTRACT_VALIDATION_FAILURE* = 13.evmc_status_code

  # An argument to a state accessing method has a value outside of the
  # accepted range of values.
  EVMC_ARGUMENT_OUT_OF_RANGE* = 14.evmc_status_code

  # A WebAssembly `unreachable` instruction has been hit during execution.
  EVMC_WASM_UNREACHABLE_INSTRUCTION* = 15.evmc_status_code

  # A WebAssembly trap has been hit during execution. This can be for many
  # reasons, including division by zero, validation errors, etc.
  EVMC_WASM_TRAP* = 16.evmc_status_code

  # EVM implementation generic internal error.
  EVMC_INTERNAL_ERROR* = evmc_status_code(-1)

  # The execution of the given code and/or message has been rejected
  # by the EVM implementation.
  #
  # This error SHOULD be used to signal that the EVM is not able to or
  # willing to execute the given code type or message.
  # If an EVM returns the ::EVMC_REJECTED status code,
  # the Client MAY try to execute it in other EVM implementation.
  # For example, the Client tries running a code in the EVM 1.5. If the
  # code is not supported there, the execution falls back to the EVM 1.0.
  EVMC_REJECTED* = evmc_status_code(-2)

  # The VM failed to allocate the amount of memory needed for execution.
  EVMC_OUT_OF_MEMORY* = evmc_status_code(-3)

  # The maximum EVM revision supported.
  EVMC_MAX_REVISION* = EVMC_BERLIN

proc incl*(a: var evmc_capabilities, b: evmc_capabilities) {.inline.} =
  a = evmc_capabilities(a.uint32 or b.uint32)

proc excl*(a: var evmc_capabilities, b: evmc_capabilities) {.inline.} =
  a = evmc_capabilities(a.uint32 and (not b.uint32))

proc contains*(a, b: evmc_capabilities): bool {.inline.} =
  (a.uint32 and b.uint32) != 0

proc `==`*(a, b: evmc_status_code): bool {.borrow.}
