import std/strutils
import std/macros
import std/tables
import std/sequtils
import std/options
import std/uri
import std/asyncdispatch
import std/httpclient
import std/json

import bump
import rest
import cutelog

type
  HelpText = tuple[switch: string; help: string]
  Lookup* = enum
    MeansLike = "ml: means like"
    SoundsLike = "sl: sounds like"
    SpelledLike = "sp: spelled like"
    Vocabulary = "v: vocabulary"
    Topics = "topics: concepts like"
    LeftContext = "lc: left context"
    RightContext = "rc: right context"
    MaximumResults = "max: limit results"
    QueryEcho = "qe: reproduce query"

  Related* = enum
    jja = "jja: nouns"
    jjb = "jjb: adjectives"
    syn = "syn: synonyms"
    trg = "trg: triggers"
    ant = "ant: antonyms"
    spc = "spc: kind of"
    gen = "gen: hyponyms"
    com = "com: holonyms"
    par = "par: meronyms"
    bga = "bga: followers"
    bgb = "bgb: leaders"
    rhy = "rhy: ideal rhymes"
    nry = "nry: near rhymes"
    hom = "hom: homophones"
    cns = "cns: consonant"

  MetaData* = enum
    Definitions = "d: definitions"
    PartsOfSpeech = "p: parts of speech"
    SyllableCount = "s: syllable count"
    Pronunciation = "r: pronunciation"
    WordFrequency = "f: word frequency"

  Suggestion* = enum
    PrefixHint = "s: starts with"
    MaximumSuggestions = "max: limit results"
    SuggestionVocabulary = "v: vocabulary"

  Result* = object
    word: string
    score: int
    syllables: range[1 .. int.high]

  QueryTable[T] = Table[T, string]
  QueryKind* = enum
    Lookups = "/words"
    Suggestions = "/sug"

  MuseCall* = object
    results: seq[Result]
    case kind: QueryKind
    of Lookups:
      lookup: QueryTable[Lookup]
      metadata: QueryTable[MetaData]
      related: QueryTable[Related]
    of Suggestions:
      suggestion: QueryTable[Suggestion]

proc newDataMuseCall*(url: Uri; name = "datamuse"): RestCall =
  result = RestCall(name: name, meth: HttpGet, url: url)

proc newMuseCall*(kind: QueryKind;
                  args: openArray[tuple[key, val: string]]): RestCall =
  const
    datamuseUrl = "https://api.datamuse.com/".parseUri
  var
    args = toSeq args
    url = datamuseUrl / $kind ? args
  result = newDataMuseCall(url, name = "datamuse " & $kind)

template newWordsCall*(args: openArray[tuple[key, val: string]]): RestCall =
  result = Lookups.newMuseCall args

template newSuggCall*(args: openArray[tuple[key, val: string]]): RestCall =
  result = Suggestions.newMuseCall args

proc keyHelp(switch: string): HelpText =
  ## produce name and help string from switch enum
  const
    splat = ": "
  let
    seqs = split(switch, splat, maxsplit = 1)
  result = (switch: seqs[0], help: seqs[^1])

proc addArgument(params: var seq[NimNode];
                 help: var NimNode; args: NimNode;
                 switch: enum; prefix = ""): NimNode =
  let
    h = keyHelp($switch)
    sw = ident(h.switch)
    sws = newStrLitNode(prefix & h.switch)
  params.add newIdentDefs(sw, ident"string", default = newStrLitNode"")
  help.add newColonExpr(newLit(h.switch), newLit(h.help))
  result = quote do:
    if `sw` != "":
      `args`.add (`sws`, `sw`)

macro makeMuse(kind: QueryKind; name: string): untyped =
  ## generate some cligen entry points that are correct by construction
  let
    args = ident"args"
    call = ident"call"
    helpIdent = ident($name & "_help")
    name = postfix(ident($name), "*")

  # setup each procedure
  var
    help = newNimNode(nnkTableConstr)
    params: seq[NimNode] = @[ident"int"]
    body = newStmtList()
  body.add quote do:
    var
      `args`: seq[tuple[key, val: string]]

  # build the custom parameter processing per procedure
  case $kind
  of "Lookups":
    for switch in Lookup.items:
      body.add params.addArgument(help, args, switch)
    for switch in MetaData.items:
      body.add params.addArgument(help, args, switch)
    for switch in Related.items:
      body.add params.addArgument(help, args, switch, prefix = "rel_")
    body.add quote do:
      var `call` = newMuseCall(Lookups, `args`)
  of "Suggestions":
    for switch in Suggestion.items:
      body.add params.addArgument(help, args, switch)
    body.add quote do:
      var `call` = newMuseCall(Suggestions, `args`)

  # parsing results is common to all procedures
  body.add quote do:
    let
      request = newRecallable(`call`)
      response = request.retried
      js = parseJson(waitfor response.body)
    debug js.pretty
    return 0

  result = newStmtList()
  # create the help table
  result.add newConstStmt(helpIdent, newCall(ident"toTable", help))
  # generate the proc node
  result.add newProc(name, params, body)
  echo result.repr

  when false:
    for result in js.items:
      `call`.results.add Result(word: result["word"].getStr,
                               score: result{"score"}.getInt,
                               syllables: result{"numSyllables"}.getInt)

makeMuse(Suggestions, "suggest")
makeMuse(Lookups, "lookup")

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

  dispatchMulti [suggest, help=suggest_help], [lookup, help=lookup_help]
