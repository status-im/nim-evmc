## EVM-C -- C interface to Ethereum Virtual Machine
##
## ## High level design rules
##
## 1. Pass function arguments and results by value.
##    This rule comes from modern C++ and tries to avoid costly alias analysis
##    needed for optimization. As the result we have a lots of complex structs
##    and unions. And variable sized arrays of bytes cannot be passed by copy.
## 2. The EVM operates on integers so it prefers values to be host-endian.
##    On the other hand, LLVM can generate good code for byte swaping.
##    The interface also tries to match host application "natural" endianess.
##    I would like to know what endianess you use and where.
##
## ## Terms
##
## 1. EVM  -- an Ethereum Virtual Machine instance/implementation.
## 2. Host -- an entity controlling the EVM. The Host requests code execution
##            and responses to EVM queries by callback functions.
##
## @defgroup EVMC EVM-C
## @{

{.deadCodeElim: on.}
when defined(windows):
  const
    libevmjit* = "libevmjit.dll"
elif defined(macosx):
  const
    libevmjit* = "libevmjit.dylib"
else:
  const
    libevmjit* = "libevmjit.so"
##  BEGIN Python CFFI declarations

const
  ## The EVM-C ABI version number of the interface declared in this file.
  EVM_ABI_VERSION* = 0



type
  evmc_uint256be* {.bycopy.} = object
    ## Big-endian 256-bit integer.
    ##
    ## 32 bytes of data representing big-endian 256-bit integer. I.e. bytes[0] is
    ## the most significant byte, bytes[31] is the least significant byte.
    ## This type is used to transfer to/from the VM values interpreted by the user
    ## as both 256-bit integers and 256-bit hashes.
    bytes*: array[32, uint8]    ## The 32 bytes of the big-endian integer or hash.

  evmc_address* {.bycopy.} = object
    ## Big-endian 160-bit hash suitable for keeping an Ethereum address.
    bytes*: array[20, uint8]    ## The 20 bytes of the hash.

  evmc_call_kind* {.size: sizeof(cint).} = enum
    ## The kind of call-like instruction.
    EVM_CALL = 0,         ## Request CALL.
    EVM_DELEGATECALL = 1, ## Request DELEGATECALL. The value param ignored.
    EVM_CALLCODE = 2,     ## Request CALLCODE.
    EVM_CREATE = 3        ## Request CREATE. Semantic of some params changes.

  evmc_flags* {.size: sizeof(cint).} = enum
    ## The flags for ::evm_message.
    EVM_STATIC = 1

  evmc_message* {.bycopy.} = object
    ## The message describing an EVM call,
    ## including a zero-depth calls from a transaction origin.

    destination*: evmc_address
    ## The destination of the message.

    sender*: evmc_address
    ## The sender of the message

    value*: evmc_uint256be
    ## The amount of Ether transferred with the message.

    input_data*: ptr uint8
    ## The message input data. This MAY be NULL.

    input_size*: csize
    ## The size of the message input data.
    ## If input_data is NULL this MUST be 0.

    code_hash*: evmc_uint256be
    ## The optional hash of the code of the destination account.
    ## The null hash MUST be used when not specified.

    gas*: int64
    ## The amount of gas for message execution.

    depth*: int32
    ## The call depth.

    kind*: evmc_call_kind
    ## The kind of the call. For zero-depth calls ::EVM_CALL SHOULD be used.

    flags*: uint32
    ## Additional flags modifying the call execution behavior.
    ## In the current version the only valid values are ::EVM_STATIC or 0.

  evmc_tx_context* {.bycopy.} = object
    ## The transaction and block data for execution.
    tx_gas_price*: evmc_uint256be     ## The transaction gas price.
    tx_origin*: evmc_address          ## The transaction origin account.
    block_coinbase*: evmc_address     ## The miner of the block.
    block_number*: int64             ## The block number.
    block_timestamp*: int64          ## The block timestamp.
    block_gas_limit*: int64          ## The block gas limit.
    block_difficulty*: evmc_uint256be ## The block difficulty.

  evmc_get_tx_context_fn* = proc (result: ptr evmc_tx_context; context: ptr evmc_context) {.cdecl.}
    ## Get transaction context callback function.
    ##
    ## This callback function is used by an EVM to retrieve the transaction and
    ## block context.
    ##
    ## @param[out] result   The returned transaction context.
    ##                      @see ::evm_tx_context.
    ## @param      context  The pointer to the Host execution context.
    ##                      @see ::evm_context.

  evmc_get_block_hash_fn* = proc (result: ptr evmc_uint256be; context: ptr evmc_context;
                              number: int64) {.cdecl.}
  ## Get block hash callback function..
  ##
  ## This callback function is used by an EVM to query the block hash of
  ## a given block.
  ##
  ## @param[out] result   The returned block hash value.
  ## @param      context  The pointer to the Host execution context.
  ## @param      number   The block number. Must be a value between
  ##                      (and including) 0 and 255.

  evmc_status_code* {.size: sizeof(cint).} = enum
    ## The execution status code.
    EVM_INTERNAL_ERROR = -2,
    ## EVM implementation internal error.
    ##
    ## @todo We should rethink reporting internal errors. One of the options
    ##       it to allow using any negative value to represent internal errors.

    EVM_REJECTED = -1,
    ## The EVM rejected the execution of the given code or message.
    ##
    ## This error SHOULD be used to signal that the EVM is not able to or
    ## willing to execute the given code type or message.
    ## If an EVM returns the ::EVM_REJECTED status code,
    ## the Client MAY try to execute it in other EVM implementation.
    ## For example, the Client tries running a code in the EVM 1.5. If the
    ## code is not supported there, the execution falls back to the EVM 1.0.

    EVM_SUCCESS = 0,              ## Execution finished with success.
    EVM_FAILURE = 1,              ## Generic execution failure.
    EVM_OUT_OF_GAS = 2,
    EVM_BAD_INSTRUCTION = 3,
    EVM_BAD_JUMP_DESTINATION = 4,
    EVM_STACK_OVERFLOW = 5,
    EVM_STACK_UNDERFLOW = 6,
    EVM_REVERT = 7,               ## Execution terminated with REVERT opcode.
    EVM_STATIC_MODE_ERROR = 8     ## Tried to execute an operation which is restricted in static mode.

  evmc_release_result_fn* = proc (result: ptr evmc_result) {.cdecl.}
    ## Releases resources assigned to an execution result.
    ##
    ## This function releases memory (and other resources, if any) assigned to the
    ## specified execution result making the result object invalid.
    ##
    ## @param result  The execution result which resource are to be released. The
    ##                result itself it not modified by this function, but becomes
    ##                invalid and user should discard it as well.

  evmc_result* {.bycopy.} = object
    ## The EVM code execution result.
    status_code*: evmc_status_code ## The execution status code.

    gas_left*: int64
      ## The amount of gas left after the execution.
      ##
      ## If evmc_result::code is not ::EVM_SUCCESS nor ::EVM_REVERT
      ## the value MUST be 0.

    output_data*: ptr uint8
      ## The reference to output data.
      ##
      ## The output contains data coming from RETURN opcode (iff evmc_result::code
      ## field is ::EVM_SUCCESS) or from REVERT opcode.
      ##
      ## The memory containing the output data is owned by EVM and has to be
      ## freed with evmc_result::release().
      ##
      ## This MAY be NULL.

    output_size*: csize
    ## The size of the output data.
    ##
    ## If output_data is NULL this MUST be 0.

    release*: evmc_release_result_fn
    ## The pointer to a function releasing all resources associated with
    ## the result object.
    ##
    ## This function pointer is optional (MAY be NULL) and MAY be set by
    ## the EVM implementation. If set it MUST be used by the user to
    ## release memory and other resources associated with the result object.
    ## After the result resources are released the result object
    ## MUST NOT be used any more.
    ##
    ## The suggested code pattern for releasing EVM results:
    ## @code
    ## struct evmc_result result = ...;
    ## if (result.release)
    ##     result.release(&result);
    ## @endcode
    ##
    ## @note
    ## It works similarly to C++ virtual destructor. Attaching the release
    ## function to the result itself allows EVM composition.

    create_address*: evmc_address
    ## The address of the contract created by CREATE opcode.
    ##
    ## This field has valid value only if the result describes successful
    ## CREATE (evm_result::status_code is ::EVM_SUCCESS).

    padding*: array[4, uint8]
    ## Reserved data that MAY be used by a evmc_result object creator.
    ##
    ## This reserved 4 bytes together with 20 bytes from create_address form
    ## 24 bytes of memory called "optional data" within evmc_result struct
    ## to be optionally used by the evmc_result object creator.
    ##
    ## @see evmc_result_optional_data, evmc_get_optional_data().
    ##
    ## Also extends the size of the evmc_result to 64 bytes (full cache line).

  evmc_result_optional_data* {.bycopy.} = object {.union.}
    ## The union representing evmc_result "optional data".
    ##
    ## The evmc_result struct contains 24 bytes of optional data that can be
    ## reused by the obejct creator if the object does not contain
    ## evmc_result::create_address.
    ##
    ## An EVM implementation MAY use this memory to keep additional data
    ## when returning result from ::evm_execute_fn.
    ## The host application MAY use this memory to keep additional data
    ## when returning result of performed calls from ::evm_call_fn.
    ##
    ## @see evmc_get_optional_data(), evmc_get_const_optional_data().
    bytes*: array[24, uint8]
    pointer*: pointer

  evmc_account_exists_fn* = proc (context: ptr evmc_context; address: ptr evmc_address): cint {.cdecl.}
    ## Check account existence callback function
    ##
    ## This callback function is used by the EVM to check if
    ## there exists an account at given address.
    ## @param      context  The pointer to the Host execution context.
    ##                      @see ::evm_context.
    ## @param      address  The address of the account the query is about.
    ## @return              1 if exists, 0 otherwise.

  evmc_get_storage_fn* = proc (result: ptr evmc_uint256be; context: ptr evmc_context;
                              address: ptr evmc_address; key: ptr evmc_uint256be) {.cdecl.}
    ## Get storage callback function.
    ##
    ## This callback function is used by an EVM to query the given contract
    ## storage entry.
    ## @param[out] result   The returned storage value.
    ## @param      context  The pointer to the Host execution context.
    ##                      @see ::evm_context.
    ## @param      address  The address of the contract.
    ## @param      key      The index of the storage entry.

  evmc_set_storage_fn* = proc (context: ptr evmc_context; address: ptr evmc_address;
                              key: ptr evmc_uint256be; value: ptr evmc_uint256be) {.cdecl.}
    ## Set storage callback function.
    ##
    ## This callback function is used by an EVM to update the given contract
    ## storage entry.
    ## @param context  The pointer to the Host execution context.
    ##                 @see ::evm_context.
    ## @param address  The address of the contract.
    ## @param key      The index of the storage entry.
    ## @param value    The value to be stored.

  evmc_get_balance_fn* = proc (result: ptr evmc_uint256be; context: ptr evmc_context;
                              address: ptr evmc_address) {.cdecl.}
    ## Get balance callback function.
    ##
    ## This callback function is used by an EVM to query the balance of the given
    ## address.
    ## @param[out] result   The returned balance value.
    ## @param      context  The pointer to the Host execution context.
    ##                      @see ::evm_context.
    ## @param      address  The address.

  evmc_get_code_fn* = proc (result_code: ptr ptr uint8; context: ptr evmc_context;
                            address: ptr evmc_address): csize {.cdecl.}
    ## Get code callback function.
    ##
    ## This callback function is used by an EVM to get the code of a contract of
    ## given address.
    ##
    ## @param[out] result_code  The pointer to the contract code. This argument is
    ##                          optional. If NULL is provided, the host MUST only
    ##                          return the code size. It will be freed by the Client.
    ## @param      context      The pointer to the Host execution context.
    ##                          @see ::evm_context.
    ## @param      address      The address of the contract.
    ## @return                  The size of the code.

  evmc_selfdestruct_fn* = proc (context: ptr evmc_context; address: ptr evmc_address;
                                beneficiary: ptr evmc_address) {.cdecl.}
    ## Selfdestruct callback function.
    ##
    ## This callback function is used by an EVM to SELFDESTRUCT given contract.
    ## The execution of the contract will not be stopped, that is up to the EVM.
    ##
    ## @param context      The pointer to the Host execution context.
    ##                     @see ::evm_context.
    ## @param address      The address of the contract to be selfdestructed.
    ## @param beneficiary  The address where the remaining ETH is going to be
    ##                     transferred.

  evmc_emit_log_fn* = proc (context: ptr evmc_context; address: ptr evmc_address;
                            data: ptr uint8; data_size: csize; topics: ptr evmc_uint256be;
                            topics_count: csize) {.cdecl.}
    ## Log callback function.
    ##
    ## This callback function is used by an EVM to inform about a LOG that happened
    ## during an EVM bytecode execution.
    ## @param context       The pointer to the Host execution context.
    ##                      @see ::evm_context.
    ## @param address       The address of the contract that generated the log.
    ## @param data          The pointer to unindexed data attached to the log.
    ## @param data_size     The length of the data.
    ## @param topics        The pointer to the array of topics attached to the log.
    ## @param topics_count  The number of the topics. Valid values are between
    ##                      0 and 4 inclusively.

  evmc_call_fn* = proc (result: ptr evmc_result; context: ptr evmc_context;
                    msg: ptr evmc_message) {.cdecl.}
    ## Pointer to the callback function supporting EVM calls.
    ##
    ## @param[out] result  The result of the call. The result object is not
    ##                     initialized by the EVM, the Client MUST correctly
    ##                     initialize all expected fields of the structure.
    ## @param      context The pointer to the Host execution context.
    ##                     @see ::evm_context.
    ## @param      msg     Call parameters. @see ::evm_message.

  evmc_context_fn_table* {.bycopy.} = object
    ## The context interface.
    ##
    ## The set of all callback functions expected by EVM instances. This is C
    ## realisation of vtable for OOP interface (only virtual methods, no data).
    ## Host implementations SHOULD create constant singletons of this (similarly
    ## to vtables) to lower the maintenance and memory management cost.
    account_exists*: evmc_account_exists_fn
    get_storage*: evmc_get_storage_fn
    set_storage*: evmc_set_storage_fn
    get_balance*: evmc_get_balance_fn
    get_code*: evmc_get_code_fn
    selfdestruct*: evmc_selfdestruct_fn
    call*: evmc_call_fn
    get_tx_context*: evmc_get_tx_context_fn
    get_block_hash*: evmc_get_block_hash_fn
    emit_log*: evmc_emit_log_fn

  evmc_context* {.bycopy.} = object
    ## Execution context managed by the Host.
    ##
    ## The Host MUST pass the pointer to the execution context to
    ## ::evm_execute_fn. The EVM MUST pass the same pointer back to the Host in
    ## every callback function.
    ## The context MUST contain at least the function table defining the context
    ## callback interface.
    ## Optionally, The Host MAY include in the context additional data.
    fn_table*: ptr evmc_context_fn_table ## Function table defining the context interface (vtable).

  evmc_destroy_fn* = proc (evm: ptr evmc_instance) {.cdecl.}
    ## Forward declaration.
    ## Destroys the EVM instance.
    ##
    ## @param evm  The EVM instance to be destroyed.

  evmc_set_option_fn* = proc (evm: ptr evmc_instance; name: cstring; value: cstring): cint {.cdecl.}
    ## Configures the EVM instance.
    ##
    ## Allows modifying options of the EVM instance.
    ## Options:
    ## - code cache behavior: on, off, read-only, ...
    ## - optimizations,
    ##
    ## @param evm    The EVM instance to be configured.
    ## @param name   The option name. NULL-terminated string. Cannot be NULL.
    ## @param value  The new option value. NULL-terminated string. Cannot be NULL.
    ## @return       1 if the option set successfully, 0 otherwise.

  evmc_revision* {.size: sizeof(cint).} = enum
    ## EVM revision.
    ##
    ## The revision of the EVM specification based on the Ethereum
    ## upgrade / hard fork codenames.
    EVM_FRONTIER = 0, EVM_HOMESTEAD = 1, EVM_TANGERINE_WHISTLE = 2,
    EVM_SPURIOUS_DRAGON = 3, EVM_BYZANTIUM = 4, EVM_CONSTANTINOPLE = 5

  evmc_execute_fn* = proc (instance: ptr evmc_instance; context: ptr evmc_context;
                          rev: evmc_revision; msg: ptr evmc_message; code: ptr uint8;
                          code_size: csize): evmc_result {.cdecl.}
    ## Generates and executes machine code for given EVM bytecode.
    ##
    ## All the fun is here. This function actually does something useful.
    ##
    ## @param instance    A EVM instance.
    ## @param context     The pointer to the Host execution context to be passed
    ##                    to callback functions. @see ::evm_context.
    ## @param rev         Requested EVM specification revision.
    ## @param msg         Call parameters. @see ::evm_message.
    ## @param code        Reference to the bytecode to be executed.
    ## @param code_size   The length of the bytecode.
    ## @return            All execution results.

  evmc_instance* {.bycopy.} = object
    ## The EVM instance.
    ##
    ## Defines the base struct of the EVM implementation.

    abi_version*: cint
    ## EVM-C ABI version implemented by the EVM instance.
    ##
    ## For future use to detect ABI incompatibilities. The EVM-C ABI version
    ## represented by this file is in ::EVM_ABI_VERSION.
    ##
    ## @todo Consider removing this field.
    destroy*: evmc_destroy_fn
    ## Pointer to function destroying the EVM instance.
    execute*: evmc_execute_fn
    ## Pointer to function executing a code by the EVM instance.
    set_option*: evmc_set_option_fn
    ## Optional pointer to function modifying VM's options.
    ##
    ## If the VM does not support this feature the pointer can be NULL.

proc evmc_get_optional_data*(r: ptr evmc_result): ptr evmc_result_optional_data {.inline, cdecl.} =
  ## Provides read-write access to evmc_result "optional data".
  return cast[ptr evmc_result_optional_data](addr(r.create_address))

proc evmc_get_const_optional_data*(r: ptr evmc_result): ptr evmc_result_optional_data {.inline, cdecl.} =
  ## Provides read-only access to evmc_result "optional data".
  # TODO test writetracking: {.writes: [].} https://nim-lang.org/araq/writetracking.html
  return cast[ptr evmc_result_optional_data](addr(r.create_address))


##  END Python CFFI declarations

## Example of a function creating an instance of an example EVM implementation.
##
## Each EVM implementation MUST provide a function returning an EVM instance.
## The function SHOULD be named `<vm-name>_create(void)`.
##
## @return  EVM instance or NULL indicating instance creation failure.
##
## struct evmc_instance* examplevm_create(void);


