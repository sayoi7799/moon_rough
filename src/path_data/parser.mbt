// Port of path-data-parser 0.1.0 src/parser.ts (parsePath, serialize).

///|
/// One SVG path command: its letter (`M`, `l`, `A`, `z`, ...) and numeric
/// parameters, as path-data-parser represents it.
pub(all) struct Segment {
  key : Char
  data : Array[Double]
} derive(Eq, Debug)

///|
/// Why a path string could not be parsed. rough.js throws (or, for
/// `AfterClose`, loops forever) on these inputs; moon_rough reports them.
pub(all) suberror PathError {
  /// A character that is neither whitespace, a command nor a number starts at
  /// this UTF-16 offset. (rough.js crashes with a TypeError.)
  InvalidCharacter(Int)
  /// A command parameter is not a number, e.g. `L 10 Z`.
  /// (path-data-parser: "Param not a number: <mode>,<text>".)
  ParamNotANumber(Char, String)
  /// The path ends before the last command got all of its parameters.
  /// (path-data-parser: "Path data ended short".)
  EndedShort
  /// Numbers follow a `Z`/`z`, which takes no parameters. (path-data-parser
  /// pushes empty `Z` segments forever without consuming them.)
  NumberAfterClose
} derive(Eq, Debug)

///|
priv enum Token {
  Command(Char)
  Number(Double)
  End
}

///|
/// Number of parameters of each command (`PARAMS`), or -1 for non-commands.
fn param_count(key : Char) -> Int {
  match key {
    'A' | 'a' => 7
    'C' | 'c' => 6
    'Q' | 'q' | 'S' | 's' => 4
    'L' | 'l' | 'M' | 'm' | 'T' | 't' => 2
    'H' | 'h' | 'V' | 'v' => 1
    'Z' | 'z' => 0
    _ => -1
  }
}

///|
fn is_digit(c : UInt16) -> Bool {
  c >= '0' && c <= '9'
}

///|
/// Length of the number at `start`, following
/// `^(([-+]?[0-9]+(\.[0-9]*)?|[-+]?\.[0-9]+)([eE][-+]?[0-9]+)?)`, or 0.
fn number_length(d : StringView, start : Int) -> Int {
  let n = d.length()
  let mut i = start
  if i < n && (d.unsafe_get(i) == '-' || d.unsafe_get(i) == '+') {
    i += 1
  }
  let int_start = i
  while i < n && is_digit(d.unsafe_get(i)) {
    i += 1
  }
  if i > int_start {
    // [0-9]+(\.[0-9]*)?
    if i < n && d.unsafe_get(i) == '.' {
      i += 1
      while i < n && is_digit(d.unsafe_get(i)) {
        i += 1
      }
    }
  } else {
    // \.[0-9]+
    if !(i + 1 < n && d.unsafe_get(i) == '.' && is_digit(d.unsafe_get(i + 1))) {
      return 0
    }
    i += 2
    while i < n && is_digit(d.unsafe_get(i)) {
      i += 1
    }
  }
  // ([eE][-+]?[0-9]+)?, only taken when complete.
  if i < n && (d.unsafe_get(i) == 'e' || d.unsafe_get(i) == 'E') {
    let mut j = i + 1
    if j < n && (d.unsafe_get(j) == '-' || d.unsafe_get(j) == '+') {
      j += 1
    }
    if j < n && is_digit(d.unsafe_get(j)) {
      while j < n && is_digit(d.unsafe_get(j)) {
        j += 1
      }
      i = j
    }
  }
  i - start
}

///|
fn tokenize(d : StringView) -> Array[Token] raise PathError {
  let tokens = []
  let n = d.length()
  let mut i = 0
  while i < n {
    let c = d.unsafe_get(i)
    if c == ' ' || c == '\t' || c == '\r' || c == '\n' || c == ',' {
      i += 1
    } else if c < 128 && param_count(c.to_int().unsafe_to_char()) >= 0 {
      tokens.push(Command(c.to_int().unsafe_to_char()))
      i += 1
    } else {
      let len = number_length(d, i)
      if len == 0 {
        raise InvalidCharacter(i)
      }
      // The token text is `${parseFloat(match)}` and the parameter is
      // `+text`: a round trip that only turns -0 into 0.
      let value = @jsmath.parse_float(d[i:i + len])
      tokens.push(Number(if value == 0.0 { 0.0 } else { value }))
      i += len
    }
  }
  tokens.push(End)
  tokens
}

///|
/// `parsePath(d)`: splits path data into segments, keeping relative commands
/// and implicit repetitions as written (`M 1 2 3 4` is `M 1 2`, `L 3 4`).
/// Data not starting with a move-to is parsed as `"M0,0" + d`.
pub fn parse_path(d : StringView) -> Array[Segment] raise PathError {
  let tokens = tokenize(d)
  let segments = []
  let mut mode = 'B' // 'BOD' (beginning of data) in path-data-parser
  let mut index = 0
  let mut token = tokens[index]
  while !(token is End) {
    let mut count = 0
    match token {
      _ if mode == 'B' =>
        match token {
          Command('M' | 'm' as key) => {
            index += 1
            count = param_count(key)
            mode = key
          }
          _ => return parse_path("M0,0" + d.to_owned())
        }
      Number(_) => {
        count = param_count(mode)
        if count == 0 {
          raise NumberAfterClose
        }
      }
      Command(key) => {
        index += 1
        count = param_count(key)
        mode = key
      }
      End => ()
    }
    guard index + count < tokens.length() else { raise EndedShort }
    let params = []
    for i in index..<(index + count) {
      match tokens[i] {
        Number(x) => params.push(x)
        Command(key) => raise ParamNotANumber(mode, key.to_string())
        End => raise EndedShort
      }
    }
    segments.push({ key: mode, data: params, })
    index += count
    token = tokens[index]
    if mode == 'M' {
      mode = 'L'
    }
    if mode == 'm' {
      mode = 'l'
    }
  }
  segments
}

///|
/// `serialize(segments)`: the inverse of `parse_path`, formatted like
/// path-data-parser (`C x1 y1, x2 y2, x y`, numbers as in JavaScript).
pub fn serialize(segments : Array[Segment]) -> String {
  let tokens : Array[String] = []
  for segment in segments {
    let data = segment.data
    let s = data.map(@jsmath.number_to_string)
    tokens.push(segment.key.to_string())
    match segment.key {
      'C' | 'c' => {
        tokens.push(s[0])
        tokens.push(s[1] + ",")
        tokens.push(s[2])
        tokens.push(s[3] + ",")
        tokens.push(s[4])
        tokens.push(s[5])
      }
      'S' | 's' | 'Q' | 'q' => {
        tokens.push(s[0])
        tokens.push(s[1] + ",")
        tokens.push(s[2])
        tokens.push(s[3])
      }
      _ => tokens.append(s)
    }
  }
  tokens.join(" ")
}
