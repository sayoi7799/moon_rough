// The MoonBit side of examples/web: draws a shape on a canvas and returns the
// ops it drew, from a JSON description of the shape. The page gives the
// same description to rough.js and compares the two.
//
//   { "shape": "rectangle", "args": [10, 10, 200, 100],
//     "options": { "seed": 42, "roughness": 1.5, "fill": "#e66" } }
//
// `args` are the arguments of the shape method of rough.js: numbers for
// line, rectangle, ellipse, circle and arc, points for linearPath, polygon
// and curve, and the path data string for path.

///|
priv suberror SpecError {
  Bad(String)
}

///|
fn number_of(value : Json, what : String) -> Double raise SpecError {
  match value {
    Number(x, ..) => x
    _ => raise Bad("\{what} must be a number")
  }
}

///|
fn optional_number(
  obj : Map[String, Json],
  key : String,
) -> Double? raise SpecError {
  match obj.get(key) {
    None | Some(Null) => None
    Some(value) => Some(number_of(value, key))
  }
}

///|
fn optional_string(
  obj : Map[String, Json],
  key : String,
) -> String? raise SpecError {
  match obj.get(key) {
    None | Some(Null) => None
    Some(String(s)) => Some(s)
    Some(_) => raise Bad("\{key} must be a string")
  }
}

///|
fn optional_bool(
  obj : Map[String, Json],
  key : String,
) -> Bool? raise SpecError {
  match obj.get(key) {
    None | Some(Null) => None
    Some(True) => Some(true)
    Some(False) => Some(false)
    Some(_) => raise Bad("\{key} must be true or false")
  }
}

///|
fn optional_int(
  obj : Map[String, Json],
  key : String,
) -> Int32? raise SpecError {
  match optional_number(obj, key) {
    Some(x) => Some(x.to_int())
    None => None
  }
}

///|
fn optional_numbers(
  obj : Map[String, Json],
  key : String,
) -> Array[Double]? raise SpecError {
  match obj.get(key) {
    None | Some(Null) => None
    Some(Array(items)) => Some(items.map(v => number_of(v, key)))
    Some(_) => raise Bad("\{key} must be a list of numbers")
  }
}

///|
fn options_of(obj : Map[String, Json]) -> @core.Options raise SpecError {
  @core.Options::new(
    max_randomness_offset?=optional_number(obj, "maxRandomnessOffset"),
    roughness?=optional_number(obj, "roughness"),
    bowing?=optional_number(obj, "bowing"),
    stroke?=optional_string(obj, "stroke"),
    stroke_width?=optional_number(obj, "strokeWidth"),
    curve_fitting?=optional_number(obj, "curveFitting"),
    curve_tightness?=optional_number(obj, "curveTightness"),
    curve_step_count?=optional_number(obj, "curveStepCount"),
    fill?=optional_string(obj, "fill"),
    fill_style?=match optional_string(obj, "fillStyle") {
      Some(name) => Some(@core.FillStyle::from_name(name))
      None => None
    },
    fill_weight?=optional_number(obj, "fillWeight"),
    hachure_angle?=optional_number(obj, "hachureAngle"),
    hachure_gap?=optional_number(obj, "hachureGap"),
    simplification?=optional_number(obj, "simplification"),
    dash_offset?=optional_number(obj, "dashOffset"),
    dash_gap?=optional_number(obj, "dashGap"),
    zigzag_offset?=optional_number(obj, "zigzagOffset"),
    seed?=optional_int(obj, "seed"),
    stroke_line_dash?=optional_numbers(obj, "strokeLineDash"),
    stroke_line_dash_offset?=optional_number(obj, "strokeLineDashOffset"),
    fill_line_dash?=optional_numbers(obj, "fillLineDash"),
    fill_line_dash_offset?=optional_number(obj, "fillLineDashOffset"),
    disable_multi_stroke?=optional_bool(obj, "disableMultiStroke"),
    disable_multi_stroke_fill?=optional_bool(obj, "disableMultiStrokeFill"),
    preserve_vertices?=optional_bool(obj, "preserveVertices"),
    fixed_decimal_place_digits?=optional_int(obj, "fixedDecimalPlaceDigits"),
    fill_shape_roughness_gain?=optional_number(obj, "fillShapeRoughnessGain"),
  )
}

///|
fn numbers_of(
  args : Json,
  count : Int32,
  shape : String,
) -> Array[Double] raise SpecError {
  match args {
    Array(items) if items.length() >= count =>
      items.map(v => number_of(v, "an argument of \{shape}"))
    _ => raise Bad("\{shape} needs \{count} numbers")
  }
}

///|
fn points_of(args : Json) -> Array[(Double, Double)] raise SpecError {
  match args {
    Array(items) =>
      items.map(item => {
        match item {
          Array([x, y]) => (number_of(x, "a point"), number_of(y, "a point"))
          _ => raise Bad("a point is [x, y]")
        }
      })
    _ => raise Bad("points must be a list of [x, y]")
  }
}

///|
fn drawable_of(spec : String) -> @core.Drawable raise SpecError {
  let json = @json.parse(spec) catch {
    _ => raise Bad("the description is not valid JSON")
  }
  guard json is Object(obj) else { raise Bad("expected an object") }
  let shape = match obj.get("shape") {
    Some(String(s)) => s
    _ => raise Bad("shape is missing")
  }
  let args = obj.get("args").unwrap_or(Json::null())
  let options = match obj.get("options") {
    Some(Object(o)) => options_of(o)
    _ => @core.Options::new()
  }
  let generator = @core.Generator::new(
    source=@random.RandomSource::park_miller(1),
  )
  match shape {
    "line" => {
      let a = numbers_of(args, 4, shape)
      generator.line(a[0], a[1], a[2], a[3], options~)
    }
    "rectangle" => {
      let a = numbers_of(args, 4, shape)
      generator.rectangle(a[0], a[1], a[2], a[3], options~)
    }
    "ellipse" => {
      let a = numbers_of(args, 4, shape)
      generator.ellipse(a[0], a[1], a[2], a[3], options~)
    }
    "circle" => {
      let a = numbers_of(args, 3, shape)
      generator.circle(a[0], a[1], a[2], options~)
    }
    "arc" => {
      let a = numbers_of(args, 6, shape)
      let closed = match args {
        Array(items) if items.length() > 6 =>
          number_of(items[6], "closed") != 0.0
        _ => false
      }
      generator.arc(a[0], a[1], a[2], a[3], a[4], a[5], closed~, options~)
    }
    "linearPath" => generator.linear_path(points_of(args), options~)
    "polygon" => generator.polygon(points_of(args), options~)
    "curve" => generator.curve(points_of(args), options~)
    "path" =>
      match args {
        String(d) =>
          generator.path(d, options~) catch {
            _ => raise Bad("the path data is not valid")
          }
        _ => raise Bad("path needs the path data as a string")
      }
    _ => raise Bad("unknown shape \{shape}")
  }
}

///|
/// Draws the shape described by `spec` on `ctx` (a canvas 2D context).
/// Returns "" on success and a message otherwise.
pub fn draw(ctx : @canvas.JsContext, spec : String) -> String {
  try drawable_of(spec) catch {
    Bad(message) => message
  } noraise {
    drawable => {
      @canvas.draw(ctx, drawable)
      ""
    }
  }
}

///|
fn op_json(op : @core.Op) -> Json {
  Json::object({
    "op": Json::string(op.name()),
    "data": Json::array(op.data().map(fn(x) { Json::number(x) })),
  })
}

///|
/// The ops of the shape described by `spec` as JSON, in the shape of
/// rough.js' `drawable.sets`: `{ "shape", "sets": [{ "type", "ops":
/// [{ "op", "data" }] }] }`, or `{ "error" }`.
pub fn generate(spec : String) -> String {
  let json = try drawable_of(spec) catch {
    Bad(message) => Json::object({ "error": Json::string(message) })
  } noraise {
    drawable =>
      Json::object({
        "shape": Json::string(drawable.shape.name()),
        "sets": Json::array(
          drawable.sets.map(fn(set) {
            Json::object({
              "type": Json::string(set.kind.name()),
              "ops": Json::array(set.ops.map(op_json)),
            })
          }),
        ),
      })
  }
  json.stringify()
}

///|
pub fn version() -> String {
  "moon_rough"
}
