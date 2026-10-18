// Writes gallery.svg (to stdout): every shape with every fill style.
//
//   moon run src/examples/gallery > gallery.svg

///|
const CELL_W : Double = 150.0

///|
const CELL_H : Double = 130.0

///|
const LEFT : Double = 110.0

///|
const TOP : Double = 40.0

///|
fn label(
  x : Double,
  y : Double,
  text : String,
  anchor? : String = "middle",
) -> String {
  "<text x=\"\{x}\" y=\"\{y}\" font-family=\"sans-serif\" font-size=\"13\" fill=\"#333\" text-anchor=\"\{anchor}\">\{text}</text>"
}

///|
/// Draws one shape into the cell whose top-left corner is (x, y).
fn draw_shape(
  gen : @moon_rough.Generator,
  shape : String,
  x : Double,
  y : Double,
  options : @moon_rough.Options,
) -> @moon_rough.Drawable {
  match shape {
    "rectangle" => gen.rectangle(x + 20.0, y + 20.0, 110.0, 80.0, options~)
    "ellipse" => gen.ellipse(x + 75.0, y + 60.0, 120.0, 80.0, options~)
    "circle" => gen.circle(x + 75.0, y + 60.0, 90.0, options~)
    "polygon" =>
      gen.polygon(
        [
          (x + 75.0, y + 12.0),
          (x + 135.0, y + 50.0),
          (x + 112.0, y + 108.0),
          (x + 38.0, y + 108.0),
          (x + 15.0, y + 50.0),
        ],
        options~,
      )
    "arc" =>
      gen.arc(
        x + 75.0,
        y + 62.0,
        120.0,
        95.0,
        @jsmath.PI * 0.15,
        @jsmath.PI * 1.65,
        closed=true,
        options~,
      )
    "curve" =>
      gen.curve(
        [
          (x + 15.0, y + 100.0),
          (x + 40.0, y + 15.0),
          (x + 80.0, y + 85.0),
          (x + 135.0, y + 20.0),
          (x + 130.0, y + 110.0),
        ],
        options~,
      )
    _ =>
      // path: a heart with a relative arc
      gen.path(
        "M \{x + 75.0} \{y + 105.0} L \{x + 20.0} \{y + 50.0} a 27 27 0 0 1 55 -25 a 27 27 0 0 1 55 25 Z",
        options~,
      ) catch {
        _ => panic()
      }
  }
}

///|
fn main {
  let gen = @moon_rough.generator(
    source=@moon_rough.RandomSource::park_miller(2024),
  )
  let shapes = [
    "rectangle", "ellipse", "circle", "polygon", "arc", "curve", "path",
  ]
  let styles : Array[@moon_rough.FillStyle?] = [
    None,
    Some(Hachure),
    Some(Solid),
    Some(Zigzag),
    Some(CrossHatch),
    Some(Dots),
    Some(Dashed),
    Some(ZigzagLine),
  ]
  let colors = [
    "none", "#e03131", "#f08c00", "#2f9e44", "#1971c2", "#9c36b5", "#0c8599", "#e8590c",
  ]
  let content = StringBuilder()
  content.write_string(
    label(
      LEFT + CELL_W * 3.5,
      24.0,
      "moon_rough — rough.js 4.6.6 ported to MoonBit",
    ),
  )
  for i, shape in shapes {
    content.write_string(
      label(LEFT + CELL_W * i.to_double() + CELL_W / 2.0, TOP + 14.0, shape),
    )
  }
  for row, style in styles {
    let y = TOP + 20.0 + CELL_H * row.to_double()
    let name = match style {
      Some(style) => style.name()
      None => "stroke only"
    }
    content.write_string(
      label(LEFT - 12.0, y + CELL_H / 2.0, name, anchor="end"),
    )
    for col, shape in shapes {
      let x = LEFT + CELL_W * col.to_double()
      let seed = 1 + row * 16 + col
      let options = match style {
        Some(fill_style) =>
          @moon_rough.Options::new(
            seed~,
            fill=colors[row],
            fill_style~,
            hachure_gap=if fill_style == Dots { 9.0 } else { 6.0 },
            fill_weight=if fill_style == Dots { 2.0 } else { 1.2 },
            stroke_width=1.5,
            fixed_decimal_place_digits=2,
          )
        None =>
          @moon_rough.Options::new(
            seed~,
            stroke_width=1.5,
            fixed_decimal_place_digits=2,
          )
      }
      content.write_string(
        @moon_rough.drawable_to_svg(draw_shape(gen, shape, x, y, options)),
      )
    }
  }
  // Open shapes without a fill.
  let y = TOP + 20.0 + CELL_H * styles.length().to_double()
  let options = @moon_rough.Options::new(
    seed=999,
    stroke_width=1.5,
    roughness=1.8,
    fixed_decimal_place_digits=2,
  )
  content.write_string(
    label(LEFT - 12.0, y + CELL_H / 2.0, "open shapes", anchor="end"),
  )
  let open = [
    gen.line(LEFT + 15.0, y + 100.0, LEFT + 135.0, y + 20.0, options~),
    gen.linear_path(
      [
        (LEFT + CELL_W + 15.0, y + 100.0),
        (LEFT + CELL_W + 55.0, y + 20.0),
        (LEFT + CELL_W + 95.0, y + 100.0),
        (LEFT + CELL_W + 135.0, y + 20.0),
      ],
      options~,
    ),
    gen.arc(
      LEFT + CELL_W * 2.0 + 75.0,
      y + 60.0,
      110.0,
      90.0,
      0.0,
      @jsmath.PI * 1.2,
      options~,
    ),
    gen.curves(
      [
        [
          (LEFT + CELL_W * 3.0 + 15.0, y + 40.0),
          (LEFT + CELL_W * 3.0 + 75.0, y + 10.0),
          (LEFT + CELL_W * 3.0 + 135.0, y + 40.0),
        ],
        [
          (LEFT + CELL_W * 3.0 + 15.0, y + 100.0),
          (LEFT + CELL_W * 3.0 + 75.0, y + 70.0),
          (LEFT + CELL_W * 3.0 + 135.0, y + 100.0),
        ],
      ],
      options~,
    ),
    gen.rectangle(
      LEFT + CELL_W * 4.0 + 20.0,
      y + 20.0,
      110.0,
      80.0,
      options=@moon_rough.Options::new(
        seed=1000,
        roughness=0.0,
        stroke_width=1.5,
        fixed_decimal_place_digits=2,
      ),
    ),
    gen.rectangle(
      LEFT + CELL_W * 5.0 + 20.0,
      y + 20.0,
      110.0,
      80.0,
      options=@moon_rough.Options::new(
        seed=1001,
        roughness=3.0,
        bowing=6.0,
        stroke_width=1.5,
        fixed_decimal_place_digits=2,
      ),
    ),
  ]
  let captions = [
    "line", "linearPath", "open arc", "curves", "roughness 0", "roughness 3",
  ]
  for i, d in open {
    content.write_string(@moon_rough.drawable_to_svg(d))
    content.write_string(
      label(
        LEFT + CELL_W * i.to_double() + CELL_W / 2.0,
        y + CELL_H - 8.0,
        captions[i],
      ),
    )
  }
  let width = LEFT + CELL_W * shapes.length().to_double() + 20.0
  let height = y + CELL_H + 10.0
  println(
    @moon_rough.svg_document(
      width,
      height,
      content.to_string(),
      background="#fff",
    ),
  )
}
