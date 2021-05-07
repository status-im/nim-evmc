# Nim Ethereum EVM-C

[![Build Status (Travis)](https://img.shields.io/travis/status-im/nim-evmc/master.svg?label=Linux%20/%20macOS "Linux/macOS build status (Travis)")](https://travis-ci.org/status-im/nim-evmc)
[![Windows build status (Appveyor)](https://img.shields.io/appveyor/ci/nimbus/nim-evmc/master.svg?label=Windows "Windows build status (Appveyor)")](https://ci.appveyor.com/project/nimbus/nim-evmc)
[![License: Apache](https://img.shields.io/badge/License-Apache%202.0-blue.svg)](https://opensource.org/licenses/Apache-2.0)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](https://opensource.org/licenses/MIT)
![Stability: experimental](https://img.shields.io/badge/stability-experimental-orange.svg)

## Introduction

Nim&nbsp;EVMC - EVMC binary compatible interface

This the Nim version of EVMC, the [Ethereum Client-VM Connector
API](https://github.com/ethereum/evmc):

> The EVMC is the low-level ABI between Ethereum Virtual Machines (EVMs) and
> Ethereum Clients. On the EVM side it supports classic EVM1 and
> [ewasm](https://github.com/ewasm/design). On the Client-side it defines the
> interface for EVM implementations to access Ethereum environment and state.

EVMC has [detailed documentation](https://evmc.ethereum.org/).  It is mainly of
interest to developers of Ethereum clients and Ethereum Virtual Machines, but
you can learn interesting things about how the EVM fits into the Ethereum
system from what kinds of calls are in this API.

## Uses

Nim&nbsp;EVMC is a core component of
[Nimbus&nbsp;Eth1](https://github.com/status-im/nimbus-eth1), an Ethereum
client written in Nim, designed to use minimal system resources and run on
resource-limited devices.  (See also its sibling project
[Nimbus&nbsp;Eth2](https://github.com/status-im/nimbus-eth1), which is very
active on the Ethereum 2 proof-of-stake network already!)

Nim&nbsp;EVMC does not have a large test suite, just a basic one.  But it is
tested by daily extensive use with Nimbus&nbsp;Eth1, and has also been tested
in the past with [The Ethereum EVM JIT](https://github.com/ethereum/evmjit).

EVM JIT is no longer maintained, and we don't use it any more.  See
[EVMC](https://github.com/ethereum/evmc) for more recent developments with
other EVMs and clients.  (Fun fact: EVMC was originally part of EVM JIT until
it was forked off to support many EVMs).

## Installation

Nim&nbsp;EVMC can be used as a standard Nimble package `nim-evm`.  The Nim
interface to EVMC is available as:

```nim
import evmc/evmc
```

All the EVMC types, enums and functions are available in Nim, with the standard
names defined in the [EVMC Documentation](https://github.com/ethereum/evmc).

Additional "glue" functions to call through the indirect structures are
available through `import evmc/evmc_nim`.  However, `evmc/evmc_nim` is not used
by Nimbus&nbsp;Eth1 so it's mainly useful as an example.  It is used by the
tests in this package though.

To run this package's tests, simply run `nimble test`.  It exercises calls
between C and Nim in both directions and of course everything should pass.

It's not a thorough test of EVM functionality, which would be rather complex.
There's no need, because there are other extensive EVM testsuites, not designed
specially for EVMC, that can be used with Nim&nbsp;EVMC.

If building EVM JIT (no longer maintained), you need to build it as a shared
library by replacing ```add_library(evmjit ${SOURCES} gen/BuildInfo.gen.h)```
with `add_library(evmjit SHARED ${SOURCES} gen/BuildInfo.gen.h)` in file
`libevmjit/CMakeLists`.

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
