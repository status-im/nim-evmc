# Nim Ethereum EVM-C

[![Build Status (Travis)](https://img.shields.io/travis/status-im/nim-evmc/master.svg?label=Linux%20/%20macOS "Linux/macOS build status (Travis)")](https://travis-ci.org/status-im/nim-evmc)
[![Windows build status (Appveyor)](https://img.shields.io/appveyor/ci/nimbus/nim-evmc/master.svg?label=Windows "Windows build status (Appveyor)")](https://ci.appveyor.com/project/nimbus/nim-evmc)
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

This package is licensed under either of

- Apache License, version 2.0, ([LICENSE-APACHEv2](LICENSE-APACHEv2))
- MIT license ([LICENSE-MIT](LICENSE-MIT))

at your option. The files in this package (except those mentioned below) may
not be copied, modified, or distributed except according to those terms.

Files under subdirectory `tests/evmc_c` are third-party files from [Ethereum
Client-VM Connector API (EVMC)](https://github.com/ethereum/evmc), and may only
be used, copied, modified or distributed according to the licensing terms of
that distribution.  Those terms are the Apache License, version 2.0,
([LICENSE-APACHEv2](LICENSE-APACHEv2)).
