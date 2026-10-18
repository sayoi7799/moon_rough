// Port of path-data-parser 0.1.0 src/absolutize.ts.

///|
/// `absolutize(segments)`: rewrites relative commands as absolute ones
/// (`m` -> `M`, `c` -> `C`, ..., `z` -> `Z`).
pub fn absolutize(segments : Array[Segment]) -> Array[Segment] {
  let mut cx = 0.0
  let mut cy = 0.0
  let mut subx = 0.0
  let mut suby = 0.0
  let out = []
  // `data.map((d, i) => (i % 2) ? (d + cy) : (d + cx))`
  fn shift(data : Array[Double], cx : Double, cy : Double) -> Array[Double] {
    data.mapi(fn(i, d) { if i % 2 != 0 { d + cy } else { d + cx } })
  }

  for segment in segments {
    let data = segment.data
    match segment.key {
      'M' => {
        out.push({ key: 'M', data: data.copy(), })
        cx = data[0]
        cy = data[1]
        subx = data[0]
        suby = data[1]
      }
      'm' => {
        cx += data[0]
        cy += data[1]
        out.push({ key: 'M', data: [cx, cy], })
        subx = cx
        suby = cy
      }
      'L' => {
        out.push({ key: 'L', data: data.copy(), })
        cx = data[0]
        cy = data[1]
      }
      'l' => {
        cx += data[0]
        cy += data[1]
        out.push({ key: 'L', data: [cx, cy], })
      }
      'C' => {
        out.push({ key: 'C', data: data.copy(), })
        cx = data[4]
        cy = data[5]
      }
      'c' => {
        let newdata = shift(data, cx, cy)
        out.push({ key: 'C', data: newdata, })
        cx = newdata[4]
        cy = newdata[5]
      }
      'Q' => {
        out.push({ key: 'Q', data: data.copy(), })
        cx = data[2]
        cy = data[3]
      }
      'q' => {
        let newdata = shift(data, cx, cy)
        out.push({ key: 'Q', data: newdata, })
        cx = newdata[2]
        cy = newdata[3]
      }
      'A' => {
        out.push({ key: 'A', data: data.copy(), })
        cx = data[5]
        cy = data[6]
      }
      'a' => {
        cx += data[5]
        cy += data[6]
        out.push({
          key: 'A',
          data: [data[0], data[1], data[2], data[3], data[4], cx, cy],
        })
      }
      'H' => {
        out.push({ key: 'H', data: data.copy(), })
        cx = data[0]
      }
      'h' => {
        cx += data[0]
        out.push({ key: 'H', data: [cx], })
      }
      'V' => {
        out.push({ key: 'V', data: data.copy(), })
        cy = data[0]
      }
      'v' => {
        cy += data[0]
        out.push({ key: 'V', data: [cy], })
      }
      'S' => {
        out.push({ key: 'S', data: data.copy(), })
        cx = data[2]
        cy = data[3]
      }
      's' => {
        let newdata = shift(data, cx, cy)
        out.push({ key: 'S', data: newdata, })
        cx = newdata[2]
        cy = newdata[3]
      }
      'T' => {
        out.push({ key: 'T', data: data.copy(), })
        cx = data[0]
        cy = data[1]
      }
      't' => {
        cx += data[0]
        cy += data[1]
        out.push({ key: 'T', data: [cx, cy], })
      }
      'Z' | 'z' => {
        out.push({ key: 'Z', data: [], })
        cx = subx
        cy = suby
      }
      _ => ()
    }
  }
  out
}
