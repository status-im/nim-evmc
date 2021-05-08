# Nim&nbsp;EVMC - Ethereum VM binary compatible interface

<div align=right>

[![License: Apache](https://img.shields.io/badge/License-Apache%202.0-blue.svg)](https://opensource.org/licenses/Apache-2.0)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](https://opensource.org/licenses/MIT)
![Stability: unstable](https://img.shields.io/badge/stability-unstable-yellow.svg)
[![Build status Linux/Macos (Travis)](https://img.shields.io/travis/status-im/nim-evmc/master.svg?label=Linux%20+%20MacOS "Build status Linux/MacOS (Travis)")](https://travis-ci.org/status-im/nim-evmc)
[![Build status Windows (Appveyor)](https://img.shields.io/appveyor/ci/nimbus/nim-evmc/master.svg?label=Windows "Build status Windows (Appveyor)")](https://ci.appveyor.com/project/nimbus/nim-evmc)

</div>

## Introduction to EVMC

Nim&nbsp;EVMC - Ethereum Virtual Machine binary compatible interface.

This the Nim version of EVMC, the [Ethereum Client-VM Connector
API](https://github.com/ethereum/evmc), whose description says:

> The EVMC is the low-level ABI between Ethereum Virtual Machines (EVMs) and
> Ethereum Clients. On the EVM side it supports classic EVM1 and
> [ewasm](https://github.com/ewasm/design). On the Client-side it defines the
> interface for EVM implementations to access Ethereum environment and state.

EVMC provides a way for Ethereum applications (like
[Nimbus](https://github.com/status-im/nimbus-eth1),
[Geth](https://github.com/ethereum/go-ethereum) and
[OpenEthereum](https://github.com/openethereum/openethereum)) which use EVM
functionality to "plug in" different implementations of the EVM (or EWASM).

The interface is binary compatible, allowing different EVMs to be loaded as
shared libraries or statically linked in.  This supports innovation from
different teams in areas like performance, new operations and hard fork
support.  "Precompiles" can be loaded as separate libraries as well.  (These are
specially optimised contracts, generally for cryptography support.)

The interface also makes a good module boundary between the EVM and other parts
of a full Ethereum implementation.  EVMC has [detailed
documentation](https://evmc.ethereum.org/).  It is mainly of interest to
developers of Ethereum clients and Ethereum Virtual Machines, but you can learn
interesting things about how the EVM fits into the Ethereum system from what
kinds of calls are in this API.

## Used by

Nim&nbsp;EVMC is a core component of
**[Nimbus&nbsp;Eth1](https://github.com/status-im/nimbus-eth1)**, an Ethereum
client written in Nim, designed to use minimal system resources and run on
smaller devices.  Because EVMC provides a fairly clean module boundary between
the EVM and other parts of a full Ethereum implementation, after studying the
performance and other characteristics, Nimbus Eth1 decided to adopt EVMC as a
first class module boundary inside the project, using some extensions to get
extra functionality not in the base EVMC definition.

(See also its sibling project
[Nimbus&nbsp;Eth2](https://github.com/status-im/nimbus-eth1), which is very
active on the Ethereum 2 proof-of-stake network already!)

Nim&nbsp;EVMC by itself does not have a large test suite, just a basic one.
But it is tested by daily extensive use with Nimbus&nbsp;Eth1.

It has also been used in the past with [The Ethereum EVM
JIT](https://github.com/ethereum/evmjit).  EVMJIT is no longer maintained, and
we don't use it any more.  (Fun fact: EVMC was originally part of EVMJIT until
it was forked off to support many EVMs).

See [the EVMC main page](https://github.com/ethereum/evmc) for a more recent
list of other EVMs and clients that work with EVMC, and can in principle be
used with each other.

## Installation and test

Nim&nbsp;EVMC can be fetched and used as a standard Nimble package, `nim-evm`.
The main API is found in the file `evmc/evmc.nim` which is well commented, and
imported into other programs just with `import evmc/evmc`.

All the EVMC types, enums and functions are available, with the standard names
defined in the [EVMC Documentation](https://github.com/ethereum/evmc).

Additional "glue" functions for an EVM to use are available through `import
evmc/evmc_nim`.  However, `evmc/evmc_nim` is not used by Nimbus&nbsp;Eth1 so
it's mainly useful as an example.  It is used by the tests in this package
though.

To run this package's tests, simply run `nimble test`.  It exercises calls
between C and Nim in both directions and of course everything should pass.

It's not a thorough test of EVM functionality, which would be very complex.
There's no need, because there are other extensive EVM testsuites, not designed
specially for EVMC, that can be used with Nim&nbsp;EVMC due to its plugin
nature.

## Building EVMJIT and other EVMs

We used to test with EVMJIT, but EVMJIT is no longer maintained.  The old
version should still work, although it will be out of date for current Ethereum
developments.

To use EVMJIT, you will need to build it as a shared library by replacing
```add_library(evmjit ${SOURCES} gen/BuildInfo.gen.h)``` with
`add_library(evmjit SHARED ${SOURCES} gen/BuildInfo.gen.h)` in file
`libevmjit/CMakeLists`.

Other EVM implementations can be used, if you can build them as a shared
library.  Once you have done this, copy or modify the file `evmc/evmjit.nim` in
Nim&nbsp;EVMC with appropriate names changed.  Alternatively you can look at
the [Nimbus&nbsp;Eth1 implementation](https://github.com/status-im/nimbus-eth1)
which is more feature complete.

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
