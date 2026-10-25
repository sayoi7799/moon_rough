// A small scanner for the SVG that diago writes. It is not a general XML
// parser: it finds tags and reads their attributes, and everything it does
// not need to change is copied through byte for byte.

///|
/// The input is not an SVG document this package can read.
pub suberror SketchError {
  /// A tag, comment or quoted attribute value is not terminated; the
  /// payload says which, and where it starts (UTF-16 offset).
  Malformed(String)
} derive(Eq, Debug)

///|
priv struct Tag {
  name : String
  attrs : Array[(String, String)]
  closing : Bool
  self_closing : Bool
  /// Offset just after the closing `>`.
  end : Int32
}

///|
fn is_space(c : UInt16) -> Bool {
  c == ' ' || c == '\n' || c == '\t' || c == '\r'
}

///|
/// Offset of the first `c` at or after `from`, or -1.
fn index_of(s : StringView, c : Char, from : Int32) -> Int32 {
  let n = s.length()
  let mut i = from
  while i < n {
    if s.unsafe_get(i).to_int() == c.to_int() {
      return i
    }
    i += 1
  }
  -1
}

///|
fn starts_with_at(s : StringView, pos : Int32, pattern : String) -> Bool {
  let m = pattern.length()
  if pos + m > s.length() {
    return false
  }
  for i in 0..<m {
    if s.unsafe_get(pos + i) != pattern.code_unit_at(i) {
      return false
    }
  }
  true
}

///|
/// Offset of the first occurrence of `pattern` at or after `from`, or -1.
fn find_from(s : StringView, pattern : String, from : Int32) -> Int32 {
  let n = s.length()
  let m = pattern.length()
  let mut i = from
  while i + m <= n {
    if starts_with_at(s, i, pattern) {
      return i
    }
    i += 1
  }
  -1
}

///|
/// Reads the tag starting at `start`, which must be a `<`.
fn read_tag(s : StringView, start : Int32) -> Tag raise SketchError {
  let n = s.length()
  let mut i = start + 1
  let closing = i < n && s.unsafe_get(i) == '/'
  if closing {
    i += 1
  }
  let name_start = i
  while i < n {
    let c = s.unsafe_get(i)
    if is_space(c) || c == '/' || c == '>' {
      break
    }
    i += 1
  }
  let name = s[name_start:i].to_owned()
  let attrs = []
  while true {
    while i < n && is_space(s.unsafe_get(i)) {
      i += 1
    }
    if i >= n {
      raise Malformed("unterminated tag <\{name} at \{start}")
    }
    let c = s.unsafe_get(i)
    if c == '>' {
      return { name, attrs, closing, self_closing: false, end: i + 1, }
    }
    if c == '/' {
      if i + 1 < n && s.unsafe_get(i + 1) == '>' {
        return { name, attrs, closing, self_closing: true, end: i + 2, }
      }
      i += 1
      continue
    }
    let attr_start = i
    while i < n {
      let c = s.unsafe_get(i)
      if is_space(c) || c == '=' || c == '/' || c == '>' {
        break
      }
      i += 1
    }
    let attr_name = s[attr_start:i].to_owned()
    while i < n && is_space(s.unsafe_get(i)) {
      i += 1
    }
    if i < n && s.unsafe_get(i) == '=' {
      i += 1
      while i < n && is_space(s.unsafe_get(i)) {
        i += 1
      }
      if i >= n {
        raise Malformed("unterminated tag <\{name} at \{start}")
      }
      let quote = s.unsafe_get(i)
      if quote == '"' || quote == '\'' {
        let value_start = i + 1
        let close = index_of(s, quote.to_int().unsafe_to_char(), value_start)
        if close < 0 {
          raise Malformed(
            "unterminated attribute value in <\{name} at \{start}",
          )
        }
        attrs.push((attr_name, s[value_start:close].to_owned()))
        i = close + 1
      } else {
        let value_start = i
        while i < n {
          let c = s.unsafe_get(i)
          if is_space(c) || c == '>' {
            break
          }
          i += 1
        }
        attrs.push((attr_name, s[value_start:i].to_owned()))
      }
    } else if attr_name != "" {
      attrs.push((attr_name, ""))
    }
  }
  raise Malformed("unreachable")
}

///|
fn attr_of(attrs : Array[(String, String)], name : String) -> String? {
  for attr in attrs {
    if attr.0 == name {
      return Some(attr.1)
    }
  }
  None
}

///|
fn has_class(attrs : Array[(String, String)], token : String) -> Bool {
  match attr_of(attrs, "class") {
    Some(value) => class_tokens(value).contains(token)
    None => false
  }
}

///|
fn class_tokens(value : String) -> Array[String] {
  let tokens = []
  let mut start = -1
  let view = value[:]
  for i in 0..<view.length() {
    if is_space(view.unsafe_get(i)) {
      if start >= 0 {
        tokens.push(view[start:i].to_owned())
        start = -1
      }
    } else if start < 0 {
      start = i
    }
  }
  if start >= 0 {
    tokens.push(view[start:].to_owned())
  }
  tokens
}

///|
/// Elements whose content is copied through untouched.
fn is_opaque(name : String) -> Bool {
  match name {
    "style"
    | "defs"
    | "mask"
    | "clipPath"
    | "pattern"
    | "foreignObject"
    | "symbol"
    | "image"
    | "title"
    | "desc"
    | "script" => true
    _ => false
  }
}

///|
/// Offset just after the end tag matching the opening `tag`, counting nested
/// elements of the same name.
fn skip_element(
  s : StringView,
  tag : Tag,
  from : Int32,
) -> Int32 raise SketchError {
  let mut depth = 1
  let mut pos = from
  while true {
    let lt = index_of(s, '<', pos)
    if lt < 0 {
      raise Malformed("missing </\{tag.name}> for the element at \{from}")
    }
    if starts_with_at(s, lt, "<!--") {
      let e = find_from(s, "-->", lt + 4)
      if e < 0 {
        raise Malformed("unterminated comment at \{lt}")
      }
      pos = e + 3
      continue
    }
    if starts_with_at(s, lt, "<![CDATA[") {
      let e = find_from(s, "]]>", lt + 9)
      if e < 0 {
        raise Malformed("unterminated CDATA at \{lt}")
      }
      pos = e + 3
      continue
    }
    if starts_with_at(s, lt, "<?") || starts_with_at(s, lt, "<!") {
      let e = index_of(s, '>', lt)
      if e < 0 {
        raise Malformed("unterminated declaration at \{lt}")
      }
      pos = e + 1
      continue
    }
    let t = read_tag(s, lt)
    pos = t.end
    if t.name == tag.name {
      if t.closing {
        depth -= 1
        if depth == 0 {
          return pos
        }
      } else if !t.self_closing {
        depth += 1
      }
    }
  }
  raise Malformed("unreachable")
}
