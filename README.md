# Nim Ethereum EVM-C

[![License: Apache](https://img.shields.io/badge/License-Apache%202.0-blue.svg)](https://opensource.org/licenses/Apache-2.0)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](https://opensource.org/licenses/MIT)
![Stability: experimental](https://img.shields.io/badge/stability-experimental-orange.svg)

# Introduction

Nim EVM-C is a wrapper for EVMC, the [Ethereum Client-VM Connector API](https://github.com/ethereum/evmc).

So far, it has been tested with the [EVM JIT](https://github.com/ethereum/evmjit).

# Installation

You need to build EVM JIT as a shared library, by replacing ```add_library(evmjit ${SOURCES} gen/BuildInfo.gen.h)```
with `add_library(evmjit SHARED ${SOURCES} gen/BuildInfo.gen.h)` in libevmjit/CMakeLists.

## License

Licensed and distributed under either of

* MIT license: [LICENSE-MIT](LICENSE-MIT) or http://opensource.org/licenses/MIT

or

* Apache License, Version 2.0, ([LICENSE-APACHEv2](LICENSE-APACHEv2) or http://www.apache.org/licenses/LICENSE-2.0)

at your option. This file may not be copied, modified, or distributed except according to those terms.
