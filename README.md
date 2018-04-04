# Nim Ethereum EVM-C

Nim EVM-C is a wrapper for EVMC, the [Ethereum Client-VM Connector API](https://github.com/ethereum/evmc).

At the moment it has been tested with the [EVM JIT](https://github.com/ethereum/evmjit).

You need to build EVM JIT as a shared library by replacing `add_library(evmjit ${SOURCES} gen/BuildInfo.gen.h)`
by `add_library(evmjit SHARED ${SOURCES} gen/BuildInfo.gen.h)` in libevmjit/CMakeLists
