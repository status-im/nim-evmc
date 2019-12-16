mode = ScriptMode.Verbose

packageName   = "evmc"
version       = "0.0.2"
author        = "Status Research & Development GmbH"
description   = "A wrapper for the The Ethereum EVMC library"
license       = "Apache License 2.0"
skipDirs      = @["tests"]

requires "nim >= 0.19",
         "stew"

proc test(name: string, lang: string = "cpp") =
  if not dirExists "build":
    mkDir "build"
  --run
  switch("out", ("./build/" & name))
  setCommand lang, "tests/" & name & ".nim"

task test_debug, "Run all tests - test implementation":
  test "test_host_vm"

task test_release, "Run all tests - prod implementation":
  switch("define", "release")
  test "test_host_vm"

task test, "Run all tests - test and production implementation":
  exec "nimble test_debug"
  exec "nimble test_release"
