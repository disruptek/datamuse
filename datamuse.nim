import std/sequtils
import std/options
import std/uri
import std/asyncdispatch
import std/httpclient
import std/json

import bump
import rest
import cutelog

proc newDataMuseCall*(url: Uri; name = "datamuse"): RestCall =
  result = RestCall(name: name, meth: HttpGet, url: url)

proc newWordsCall*(args: openArray[tuple[key, val: string]]): RestCall =
  const
    wordsUrl = "https://api.datamuse.com/words".parseUri
  result = newDataMuseCall(wordsUrl ? args, name = "datamuse words")

proc newSuggCall*(args: openArray[tuple[key, val: string]]): RestCall =
  const
    suggUrl = "https://api.datamuse.com/sug".parseUri
  result = newDataMuseCall(suggUrl ? args, name = "datamuse suggestions")

proc muse(rel_rhy = ""; rel_trg = ""; rel_jja = ""; rel_jjb = "";
          sp = ""; ml = ""; sl = ""; sugg = ""; lc = "") =
  var
    args = toSeq {
      "rel_rhy": rel_rhy,
      "rel_trg": rel_trg,
      "rel_jja": rel_jja,
      "rel_jjb": rel_jjb,
      "s": sugg,
      "sp": sp,
      "lc": lc,
      "ml": ml,
      "sl": sl,
    }
  args.keepItIf it[1] != ""
  var
    call =
      if sugg != "":
        newSuggCall args
      else:
        newWordsCall args
  let
    request = newRecallable(call)
    response = request.retried
    js = parseJson(waitfor response.body)
  debug js.pretty

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

  dispatchCf muse, cmdName = "muse", cf = clCfg
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
