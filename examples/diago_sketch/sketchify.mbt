// Turns the SVG that diago writes into a hand-drawn one.
//
// Only geometry is replaced: the shapes inside `<g class="shape">`, the
// graphics inside `<marker>` (the arrowheads), and the `d` of connection
// paths. Everything else, such as text, styles, masks and the background,
// is copied through unchanged, and the colors stay with the CSS classes, so
// themes and dark mode keep working.

///|
priv enum FrameKind {
  Shape
  Marker
  Other
} derive(Eq)

///|
/// An open element. `inherited` holds the `fill`, `stroke` and
/// `stroke-width` an element below it takes from it (inside a shape or a
/// marker only).
priv struct Frame {
  kind : FrameKind
  inherited : Array[(String, String)]
}

///|
priv struct Context {
  seed : Int32
  roughness : Double
  generator : @moon_rough.Generator
  mut counter : Int32
}

///|
/// Redraws the diagram `svg` (as written by `@diago.compile`) by hand.
///
/// `seed` and `roughness` are passed to rough.js' options: the n-th replaced
/// element uses seed `seed + n`, counted in document order, so the result is
/// a pure function of the input and the arguments and does not change from
/// one run, backend or platform to another.
pub fn sketchify(
  svg : String,
  seed~ : Int32 = 1,
  roughness~ : Double = 1.0,
) -> String raise SketchError {
  let s = svg[:]
  let n = s.length()
  let out = StringBuilder()
  let ctx : Context = {
    seed,
    roughness,
    generator: @moon_rough.generator(
      source=@moon_rough.RandomSource::park_miller(1),
    ),
    counter: 0,
  }
  let stack : Array[Frame] = []
  let mut pos = 0
  while pos < n {
    let lt = index_of(s, '<', pos)
    if lt < 0 {
      out.write_view(s[pos:])
      break
    }
    out.write_view(s[pos:lt])
    // Comments, CDATA, processing instructions and declarations.
    let special_end = if starts_with_at(s, lt, "<!--") {
      let e = find_from(s, "-->", lt + 4)
      if e < 0 {
        raise Malformed("unterminated comment at \{lt}")
      }
      e + 3
    } else if starts_with_at(s, lt, "<![CDATA[") {
      let e = find_from(s, "]]>", lt + 9)
      if e < 0 {
        raise Malformed("unterminated CDATA at \{lt}")
      }
      e + 3
    } else if starts_with_at(s, lt, "<?") || starts_with_at(s, lt, "<!") {
      let e = index_of(s, '>', lt)
      if e < 0 {
        raise Malformed("unterminated declaration at \{lt}")
      }
      e + 1
    } else {
      -1
    }
    if special_end >= 0 {
      out.write_view(s[lt:special_end])
      pos = special_end
      continue
    }
    let tag = read_tag(s, lt)
    if tag.closing {
      if stack.length() > 0 {
        ignore(stack.pop())
      }
      out.write_view(s[lt:tag.end])
      pos = tag.end
      continue
    }
    if is_opaque(tag.name) && !tag.self_closing {
      let e = skip_element(s, tag, tag.end)
      out.write_view(s[lt:e])
      pos = e
      continue
    }
    let in_shape = stack.any(fn(f) { f.kind == Shape })
    let in_marker = stack.any(fn(f) { f.kind == Marker })
    let inherited = if stack.length() > 0 {
      stack[stack.length() - 1].inherited
    } else {
      []
    }
    let replaced = if (in_shape || in_marker) && tag.self_closing {
      ctx.replace_geometry(tag, in_marker, inherited)
    } else if !in_shape &&
      !in_marker &&
      tag.name == "path" &&
      tag.self_closing &&
      has_class(tag.attrs, "connection") {
      ctx.replace_connection(tag)
    } else {
      None
    }
    match replaced {
      Some(text) => out.write_string(text)
      None =>
        if tag.name == "marker" && !tag.self_closing {
          out.write_string(marker_start_tag(tag))
        } else {
          out.write_view(s[lt:tag.end])
        }
    }
    if !tag.self_closing {
      let kind = if tag.name == "g" && has_class(tag.attrs, "shape") {
        Shape
      } else if tag.name == "marker" {
        Marker
      } else {
        Other
      }
      let inside = in_shape || in_marker || kind != Other
      stack.push({
        kind,
        inherited: if inside {
          inherited_paint(inherited, tag.attrs)
        } else {
          []
        },
      })
    }
    pos = tag.end
  }
  out.to_string()
}

///|
/// A marker clips what it draws to its viewport by default; the wobble of a
/// hand-drawn arrowhead can reach outside it.
fn marker_start_tag(tag : Tag) -> String {
  let attrs = tag.attrs.filter(fn(a) { a.0 != "overflow" })
  attrs.push(("overflow", "visible"))
  write_tag("marker", attrs, false)
}

///|
fn write_tag(
  name : String,
  attrs : Array[(String, String)],
  self_closing : Bool,
) -> String {
  let out = StringBuilder()
  out.write_string("<\{name}")
  for attr in attrs {
    out.write_string(" \{attr.0}=\"\{attr.1}\"")
  }
  out.write_string(if self_closing { " />" } else { ">" })
  out.to_string()
}

///|
fn Context::next_seed(self : Context) -> Int32 {
  let seed = self.seed + self.counter
  self.counter += 1
  // Seed 0 would mean "use Math.random()" in rough.js.
  if seed == 0 {
    1
  } else {
    seed
  }
}

///|
fn number_attr(attrs : Array[(String, String)], name : String) -> Double? {
  match attr_of(attrs, name) {
    Some(value) => parse_number(value)
    None => None
  }
}

///|
fn parse_number(value : String) -> Double? {
  if value == "" {
    return None
  }
  Some(@string.parse_double(value[:])) catch {
    _ => None
  }
}

///|
/// `a b c` or `a,b,c` as numbers; `None` if anything is not a number.
fn parse_numbers(value : String) -> Array[Double]? {
  let numbers = []
  let view = value[:]
  let mut start = -1
  for i in 0..<(view.length() + 1) {
    let separator = i == view.length() ||
      is_space(view.unsafe_get(i)) ||
      view.unsafe_get(i) == ','
    if separator {
      if start >= 0 {
        match parse_number(view[start:i].to_owned()) {
          Some(x) => numbers.push(x)
          None => return None
        }
        start = -1
      }
    } else if start < 0 {
      start = i
    }
  }
  Some(numbers)
}

///|
/// The value of `name` in a `style="a:b;c:d"` attribute.
fn style_decl(attrs : Array[(String, String)], name : String) -> String? {
  guard attr_of(attrs, "style") is Some(style) else { return None }
  for decl in style.split(";") {
    if decl.split_once(":") is Some((key, value)) &&
      key.trim().to_owned() == name {
      return Some(value.trim().to_owned())
    }
  }
  None
}

///|
/// A style attribute without the declarations whose names start with
/// `drop_prefix`; `None` if nothing is left.
fn filter_style(style : String, drop_prefix : String) -> String? {
  let kept = []
  for decl in style.split(";") {
    let text = decl.trim().to_owned()
    if text == "" {
      continue
    }
    match text.split_once(":") {
      Some((key, _)) if key.trim().to_owned().has_prefix(drop_prefix) => ()
      _ => kept.push(text)
    }
  }
  if kept.length() == 0 {
    None
  } else {
    Some(kept.join(";") + ";")
  }
}

///|
/// A class attribute without the tokens that start with `drop_prefix`.
fn filter_class(value : String, drop_prefix : String) -> String? {
  let kept = class_tokens(value).filter(fn(t) { !t.has_prefix(drop_prefix) })
  if kept.length() == 0 {
    None
  } else {
    Some(kept.join(" "))
  }
}

///|
/// The paint attributes of `attrs` (attribute or `style` declaration).
fn own_paint(attrs : Array[(String, String)], name : String) -> String? {
  match attr_of(attrs, name) {
    Some(v) => Some(v)
    None => style_decl(attrs, name)
  }
}

///|
/// What the children of an element with `attrs` inherit, given what the
/// element itself inherits.
fn inherited_paint(
  parent : Array[(String, String)],
  attrs : Array[(String, String)],
) -> Array[(String, String)] {
  let out = []
  for name in ["fill", "stroke", "stroke-width"] {
    match own_paint(attrs, name) {
      Some(v) => out.push((name, v))
      None =>
        match attr_of(parent, name) {
          Some(v) => out.push((name, v))
          None => ()
        }
    }
  }
  out
}

///|
fn is_geometry_attr(name : String) -> Bool {
  match name {
    "x"
    | "y"
    | "width"
    | "height"
    | "rx"
    | "ry"
    | "cx"
    | "cy"
    | "r"
    | "points"
    | "d"
    | "x1"
    | "y1"
    | "x2"
    | "y2" => true
    _ => false
  }
}

///|
fn rounded_rect_path(
  x : Double,
  y : Double,
  w : Double,
  h : Double,
  r : Double,
) -> String {
  let r = if r > w / 2.0 { w / 2.0 } else { r }
  let r = if r > h / 2.0 { h / 2.0 } else { r }
  "M \{x + r} \{y} H \{x + w - r} A \{r} \{r} 0 0 1 \{x + w} \{y + r} V \{y + h - r} A \{r} \{r} 0 0 1 \{x + w - r} \{y + h} H \{x + r} A \{r} \{r} 0 0 1 \{x} \{y + h - r} V \{y + r} A \{r} \{r} 0 0 1 \{x + r} \{y} Z"
}

///|
fn pairs(numbers : Array[Double]) -> Array[(Double, Double)]? {
  if numbers.length() % 2 != 0 {
    return None
  }
  Some(
    Array::makei(numbers.length() / 2, fn(i) {
      (numbers[2 * i], numbers[2 * i + 1])
    }),
  )
}

///|
/// Draws the geometry element `tag` by hand. `None` leaves it as it is.
fn Context::replace_geometry(
  self : Context,
  tag : Tag,
  in_marker : Bool,
  inherited : Array[(String, String)],
) -> String? {
  let attrs = tag.attrs
  // Values in effect: the element's own, else inherited from a group.
  let fill_value = either(own_paint(attrs, "fill"), attr_of(inherited, "fill")).unwrap_or(
    "black",
  )
  let has_fill = fill_value != "none" && fill_value != "transparent"
  // An arrowhead that is a filled shape with no stroke anywhere needs an
  // outline in the fill color to look hand-drawn.
  let own_stroke = either(
    own_paint(attrs, "stroke"),
    attr_of(inherited, "stroke"),
  )
  let stroke_value = match own_stroke {
    Some(v) => Some(v)
    None => if in_marker && has_fill { Some(fill_value) } else { None }
  }
  let has_stroke = match stroke_value {
    Some(v) => v != "none"
    None => false
  }
  if !has_fill && !has_stroke {
    return None
  }
  let stroke_width = match
    either(own_paint(attrs, "stroke-width"), attr_of(inherited, "stroke-width")) {
    Some(v) => parse_number(v)
    None => Some(1.0)
  }
  guard stroke_width is Some(stroke_width) else { return None }
  let roughness = if in_marker { self.roughness * 0.5 } else { self.roughness }
  let options = @moon_rough.Options::new(
    seed=self.next_seed_for(tag),
    roughness~,
    stroke_width~,
    fill?=if has_fill { Some("x") } else { None },
    fill_style=Solid,
    stroke=if has_stroke { "x" } else { "none" },
    fixed_decimal_place_digits=2,
  )
  let g = self.generator
  let drawable = match tag.name {
    "rect" => {
      guard number_attr(attrs, "width") is Some(w) else { return None }
      guard number_attr(attrs, "height") is Some(h) else { return None }
      let x = number_attr(attrs, "x").unwrap_or(0.0)
      let y = number_attr(attrs, "y").unwrap_or(0.0)
      let rx = number_attr(attrs, "rx").unwrap_or(0.0)
      let ry = number_attr(attrs, "ry").unwrap_or(rx)
      let r = if rx > 0.0 { rx } else { ry }
      if r > 0.0 {
        g.path(rounded_rect_path(x, y, w, h, r), options~) catch {
          _ => return None
        }
      } else {
        g.rectangle(x, y, w, h, options~)
      }
    }
    "ellipse" => {
      guard number_attr(attrs, "rx") is Some(rx) else { return None }
      guard number_attr(attrs, "ry") is Some(ry) else { return None }
      let cx = number_attr(attrs, "cx").unwrap_or(0.0)
      let cy = number_attr(attrs, "cy").unwrap_or(0.0)
      g.ellipse(cx, cy, rx * 2.0, ry * 2.0, options~)
    }
    "circle" => {
      guard number_attr(attrs, "r") is Some(r) else { return None }
      let cx = number_attr(attrs, "cx").unwrap_or(0.0)
      let cy = number_attr(attrs, "cy").unwrap_or(0.0)
      g.circle(cx, cy, r * 2.0, options~)
    }
    "polygon" => {
      guard attr_of(attrs, "points") is Some(points) else { return None }
      guard parse_numbers(points) is Some(numbers) else { return None }
      guard pairs(numbers) is Some(points) else { return None }
      g.polygon(points, options~)
    }
    "path" => {
      guard attr_of(attrs, "d") is Some(d) else { return None }
      g.path(d, options~) catch {
        _ => return None
      }
    }
    "line" => {
      let x1 = number_attr(attrs, "x1").unwrap_or(0.0)
      let y1 = number_attr(attrs, "y1").unwrap_or(0.0)
      guard number_attr(attrs, "x2") is Some(x2) else { return None }
      guard number_attr(attrs, "y2") is Some(y2) else { return None }
      g.line(x1, y1, x2, y2, options~)
    }
    _ => return None
  }
  // Colors are written only where the element itself has them: otherwise
  // they come from an enclosing group and its CSS classes, which is what
  // keeps themes and dark mode working.
  let fill_attr = attr_of(attrs, "fill")
  let stroke_attr = match attr_of(attrs, "stroke") {
    Some(v) => Some(v)
    None => if own_stroke is None { stroke_value } else { None }
  }
  let out = StringBuilder()
  for set in drawable.sets {
    let d = @moon_rough.ops_to_path(set, fixed_decimals=2)
    // A fill of lines only has no area, and rough.js gives it no points.
    if d == "" {
      continue
    }
    match set.kind {
      FillPath =>
        out.write_string(
          write_tag("path", fill_path_attrs(attrs, d, fill_attr), true),
        )
      Path =>
        out.write_string(
          write_tag(
            "path",
            outline_path_attrs(attrs, d, stroke_attr, in_marker),
            true,
          ),
        )
      FillSketch => ()
    }
  }
  Some(out.to_string())
}

///|
/// The seed for the next element. Taking it from the tag as well would make
/// the seed depend on the tag's text, which can change with diago; only the
/// position counts.
fn Context::next_seed_for(self : Context, _tag : Tag) -> Int32 {
  self.next_seed()
}

///|
/// Attributes of the path that carries the fill: the color attributes and
/// the `fill-*` classes, without the stroke.
fn fill_path_attrs(
  attrs : Array[(String, String)],
  d : String,
  fill_attr : String?,
) -> Array[(String, String)] {
  let out = [("d", d)]
  if fill_attr is Some(fill) {
    out.push(("fill", fill))
  }
  out.push(("stroke", "none"))
  for attr in attrs {
    let (name, value) = attr
    if is_geometry_attr(name) ||
      name == "fill" ||
      name == "stroke" ||
      name.has_prefix("stroke-") {
      continue
    }
    if name == "class" {
      if filter_class(value, "stroke-") is Some(c) {
        out.push(("class", c))
      }
    } else if name == "style" {
      if filter_style(value, "stroke") is Some(st) {
        out.push(("style", st))
      }
    } else {
      out.push(attr)
    }
  }
  out
}

///|
/// Attributes of the path that carries the outline: the stroke, its width
/// and dashes, and the `stroke-*` classes, without the fill. For an
/// arrowhead, which only has fill classes, those become stroke classes so
/// the outline follows the theme as well.
fn outline_path_attrs(
  attrs : Array[(String, String)],
  d : String,
  stroke_attr : String?,
  in_marker : Bool,
) -> Array[(String, String)] {
  let out = [("d", d), ("fill", "none")]
  if stroke_attr is Some(stroke) {
    out.push(("stroke", stroke))
  }
  for attr in attrs {
    let (name, value) = attr
    if is_geometry_attr(name) ||
      name == "fill" ||
      name == "stroke" ||
      name.has_prefix("fill-") {
      continue
    }
    if name == "class" {
      let tokens = class_tokens(value).filter(fn(t) { !t.has_prefix("fill-") })
      if in_marker && attr_of(attrs, "stroke") is None {
        for t in class_tokens(value) {
          if t.has_prefix("fill-") {
            tokens.push("stroke-" + t[5:].to_owned())
          }
        }
      }
      if tokens.length() > 0 {
        out.push(("class", tokens.join(" ")))
      }
    } else if name == "style" {
      if filter_style(value, "fill") is Some(st) {
        out.push(("style", st))
      }
    } else {
      out.push(attr)
    }
  }
  out
}

///|
/// Redraws the `d` of a connection with rough.js, keeping its other
/// attributes (`marker-end`, `mask`, dashes). The vertices stay where they
/// are so that the arrowheads, which are placed by the browser at the end of
/// the path, still touch the shapes.
fn Context::replace_connection(self : Context, tag : Tag) -> String? {
  guard attr_of(tag.attrs, "d") is Some(d) else { return None }
  let stroke_width = match attr_of(tag.attrs, "stroke-width") {
    Some(v) => parse_number(v)
    None =>
      match style_decl(tag.attrs, "stroke-width") {
        Some(v) => parse_number(v)
        None => Some(1.0)
      }
  }
  guard stroke_width is Some(stroke_width) else { return None }
  let options = @moon_rough.Options::new(
    seed=self.next_seed(),
    roughness=self.roughness * 0.5,
    stroke_width~,
    stroke="x",
    preserve_vertices=true,
    fixed_decimal_place_digits=2,
  )
  let drawable = self.generator.path(d, options~) catch { _ => return None }
  let out = StringBuilder()
  for set in drawable.sets {
    if set.kind is Path {
      let attrs = tag.attrs.map(fn(a) {
        if a.0 == "d" {
          ("d", @moon_rough.ops_to_path(set, fixed_decimals=2))
        } else {
          a
        }
      })
      out.write_string(write_tag("path", attrs, true))
    }
  }
  Some(out.to_string())
}

///|
/// `a` if it is set, otherwise `b`.
fn[T] either(a : T?, b : T?) -> T? {
  match a {
    Some(_) => a
    None => b
  }
}
