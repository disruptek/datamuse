# datamuse

- `cpp +/ nim-1.0` [![Build Status](https://travis-ci.org/disruptek/datamuse.svg?branch=master)](https://travis-ci.org/disruptek/datamuse)
- `arc +/ cpp +/ nim-1.3` [![Build Status](https://travis-ci.org/disruptek/datamuse.svg?branch=devel)](https://travis-ci.org/disruptek/datamuse)

An interface to the datamuse API.

## Installation
```
$ nimble install datamuse
```

## Usage
```nim
import std/asyncdispatch

import rest
import datamuse

var
  call = newDataMuseCall {"rel_rhy": rhyme}
let
  request = newRecallable(call)
  response = request.retried
echo waitfor response.body
```

## Documentation
See [the documentation for the datamuse module](https://disruptek.github.io/datamuse/datamuse.html) as generated directly from the source.

## Tests
```
$ nimble test
```

## License
MIT
