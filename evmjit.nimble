mode = ScriptMode.Verbose

packageName   = "evmjit"
version       = "0.0.1"
author        = "Status Research & Development GmbH"
description   = "A wrapper for the The Ethereum EVM JIT library"
license       = "Apache License 2.0"
skipDirs      = @["tests"]

requires "nim >= 0.17.0"

proc configForTests() =
  --hints: off
  --debuginfo
  --path: "."
  --run

