import std/uri
import std/asyncdispatch
import std/httpclient
import std/options

import rest
import cutelog
import bump

const
  datamuseUrl = "https://api.datamuse.com/words".parseUri

proc newDataMuseCall*(args: openArray[tuple[key, val: string]];
                      name = "datamuse"): RestCall =
  result = RestCall(name: name, meth: HttpGet, url: datamuseUrl ? args)

proc name(rhyme = "") =

  var
    call = newDataMuseCall {"rel_rhy": rhyme}
  let
    request = newRecallable(call)
    response = request.retried
  debug waitfor response.body

when isMainModule:
  import cligen

  let
    logger = newCuteConsoleLogger()
  addHandler(logger)

  # find the version
  const
    version = projectVersion()
  if version.isSome:
    clCfg.version = $version.get
  else:
    clCfg.version = "(unknown version)"

  dispatchCf name, cmdName = "name", cf = clCfg
when false:
  dispatchCf name, cmdName = "name", cf = clCfg,
    usage = "Options(opt-arg sep :|=|spc):\n$options",
    help = {
      "patch": "increment the patch version field",
      "minor": "increment the minor version field",
      "major": "increment the major version field",
      "dry-run": "just report the projected version",
      "commit": "also commit any other unstaged changes",
      "v": "prefix the version tag with an ugly `v`",
      "nimble": "specify the nimble file to modify",
      "folder": "specify the location of the nimble file",
      "release": "also use `hub` to issue a GitHub release",
      "log-level": "specify Nim logging level",
      "manual": "manually set the new version to #.#.#",
    }
