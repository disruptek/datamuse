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
  Lookup* = enum
    MeansLike = "ml"
    SoundsLike = "sl"
    SpelledLike = "sp"
    Vocabulary = "v"
    Topics = "topics"
    LeftContext = "lc"
    RightContext = "rc"
    MaximumResults = "max"
    QueryEcho = "qe"

  Related* = enum
    jja = "jja"
    jjb = "jjb"
    syn = "syn"
    trg = "trg"
    ant = "ant"
    spc = "spc"
    gen = "gen"
    com = "com"
    par = "par"
    bga = "bga"
    bgb = "bgb"
    rhy = "rhy"
    nry = "nry"
    hom = "hom"
    cns = "cns"

  MetaData* = enum
    Definitions = "d"
    PartsOfSpeech = "p"
    SyllableCount = "s"
    Pronunciation = "r"
    WordFrequency = "f"

  Suggestion* = enum
    PrefixHint = "s"
    MaximumSuggestions = "max"
    SuggestionVocabulary = "v"

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

proc addArgument(params: var seq[NimNode]; args: NimNode;
                  switch: enum): NimNode =
  let
    sw = ident($switch)
    sws = newStrLitNode($switch)
  params.add newIdentDefs(sw, ident"string", default = newStrLitNode"")
  result = quote do:
    if `sw` != "":
      `args`.add (`sws`, `sw`)

macro makeMuse(kind: QueryKind; name: string): untyped =
  ## generate some cligen entry points that are correct by construction
  let
    args = ident"args"
    call = ident"call"
    name = postfix(ident($name), "*")

  # setup each procedure
  var
    params: seq[NimNode] = @[ident"int"]
    body = newStmtList()
  body.add quote do:
    var
      `args`: seq[tuple[key, val: string]]

  # build the custom parameter processing per procedure
  case $kind
  of "Lookups":
    for switch in Lookup.items:
      body.add params.addArgument(args, switch)
    for switch in MetaData.items:
      body.add params.addArgument(args, switch)
    for switch in Related.items:
      body.add params.addArgument(args, switch)
    body.add quote do:
      var `call` = newMuseCall(Lookups, `args`)
  of "Suggestions":
    for switch in Suggestion.items:
      body.add params.addArgument(args, switch)
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

  # generate the proc node
  result = newProc(name, params, body)
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

  dispatchMulti [suggest], [lookup], cf = clCfg
