**Nim Ethereum EVM-C**

# Introduction

Nim EVM-C is a wrapper for EVMC, the [Ethereum Client-VM Connector API](https://github.com/ethereum/evmc).

So far, it has been tested with the [EVM JIT](https://github.com/ethereum/evmjit).

# Installation

You need to build EVM JIT as a shared library, by replacing ```add_library(evmjit ${SOURCES} gen/BuildInfo.gen.h)```
with `add_library(evmjit SHARED ${SOURCES} gen/BuildInfo.gen.h)` in libevmjit/CMakeLists.

# License

May be distributed under one or both of the following:

* [Apache License, Version 2.0](https://www.apache.org/licenses/LICENSE-2.0)
* [MIT license](http://opensource.org/licenses/MIT)
