version = "0.0.1"
author = "disruptek"
description = "generate random names"
license = "MIT"
requires "nim >= 1.0.0"
requires "cligen < 1.0.0"
requires "https://github.com/disruptek/cutelog < 2.0.0"
requires "https://github.com/disruptek/rest < 2.0.0"
requires "https://github.com/disruptek/bump < 2.0.0"

bin = @["muse"]

proc execCmd(cmd: string) =
  echo "execCmd:" & cmd
  exec cmd

proc execTest(test: string) =
  execCmd "nim c           -f -r " & test
  execCmd "nim c   -d:release -r " & test
  execCmd "nim c   -d:danger  -r " & test
  execCmd "nim cpp            -r " & test
  execCmd "nim cpp -d:danger  -r " & test
  when NimMajor >= 1 and NimMinor >= 1:
    execCmd "nim c --useVersion:1.0 -d:danger -r " & test
    execCmd "nim c   --gc:arc -r " & test
    execCmd "nim cpp --gc:arc -r " & test

task test, "run tests for travis":
  execTest("tests/tmuse.nim")
