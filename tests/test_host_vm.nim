import ../evmc/[evmc, evmc_nim]

{.compile: "evmc_c/example_host.cpp".}
{.compile: "evmc_c/example_vm.c".}
{.passL: "-lstdc++"}

proc example_host_get_interface(): ptr evmc_host_interface {.importc, cdecl.}
proc example_host_create_context(tx_context: evmc_tx_context): ptr evmc_host_context {.importc, cdecl.}
proc example_host_destroy_context(context: ptr evmc_host_context) {.importc, cdecl.}
proc evmc_create_example_vm(): ptr evmc_vm {.importc, cdecl.}

proc main() =
  echo "tx_context: ", sizeof(evmc_tx_context)
  var vm = evmc_create_example_vm()
  var host = example_host_get_interface()

main()
