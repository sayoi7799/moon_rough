// fdlibm sine / cosine, compiled only for the native backend.
//
// On native, moonbitlang/core's @math.sin / @math.cos call the C library,
// whose results differ from V8's Math.sin / Math.cos in the last bit for a
// few percent of the inputs. V8 (and core on wasm / wasm-gc) use fdlibm, so
// this file carries the fdlibm algorithm to make native bit-identical too.
//
// Adapted from moonbitlang/core (math/trig_double_nonjs.mbt, math/utils.mbt,
// math/trig_double_sincos_non_native_or_js.mbt), Copyright 2026 International
// Digital Economy Academy, Apache License 2.0; which follows fdlibm:
//
// ====================================================
// Copyright (C) 1993 by Sun Microsystems, Inc. All rights reserved.
//
// Developed at SunSoft, a Sun Microsystems, Inc. business.
// Permission to use, copy, modify, and distribute this
// software is freely granted, provided that this notice
// is preserved.
// ====================================================
//
// See THIRD_PARTY_LICENSES. Changes: kept only what sin / cos need and
// replaced the internal scalbn by @math.scalbn.

///|
/// Sine, bit-identical to JavaScript's `Math.sin`.
pub fn sin(x : Double) -> Double {
  if x.is_inf() || x.is_nan() {
    return x - x
  }
  let y = [0.0, 0.0]
  if x.abs() <= PI_OVER_4 {
    return __kernel_sin(x, 0.0, 0)
  }
  let n = rem_pio2(x, y)
  match n & 3 {
    0 => __kernel_sin(y[0], y[1], 1)
    1 => __kernel_cos(y[0], y[1])
    2 => -__kernel_sin(y[0], y[1], 1)
    _ => -__kernel_cos(y[0], y[1])
  }
}

///|
/// Cosine, bit-identical to JavaScript's `Math.cos`.
pub fn cos(x : Double) -> Double {
  if x.is_inf() || x.is_nan() {
    return x - x
  }
  let y = [0.0, 0.0]
  if x.abs() <= PI_OVER_4 {
    return __kernel_cos(x, 0.0)
  }
  let n = rem_pio2(x, y)
  match n & 3 {
    0 => __kernel_cos(y[0], y[1])
    1 => -__kernel_sin(y[0], y[1], 1)
    2 => -__kernel_cos(y[0], y[1])
    _ => __kernel_sin(y[0], y[1], 1)
  }
}

///|
fn rem_pio2(x : Double, y : Array[Double]) -> Int32 {
  let hx = get_high_word(x).reinterpret_as_int()
  let ix : Int32 = hx & 0x7fffffff
  let mut z = 0.0
  if ix <= 0x3fe921fb {
    // |x| <= pi/4, no reduction needed
    y[0] = x
    y[1] = 0.0
    return 0
  }
  if ix < 0x4002d97c {
    // |x| < 3pi/4, special case with n = +-1
    if hx > 0 {
      z = x - PIO2_1
      if ix != 0x3ff921fb {
        // 33+53 bit pi is good enough
        y[0] = z - PIO2_1T
        y[1] = z - y[0] - PIO2_1T
      } else {
        // Near pi/2, use 33+33+53 bit pi
        z -= PIO2_2
        y[0] = z - PIO2_2T
        y[1] = z - y[0] - PIO2_2T
      }
      return 1
    } else {
      // Negative x
      z = x + PIO2_1
      if ix != 0x3ff921fb {
        // 33+53 bit pi is good enough
        y[0] = z + PIO2_1T
        y[1] = z - y[0] + PIO2_1T
      } else {
        // Near pi/2, use 33+33+53 bit pi
        let z = z + PIO2_2
        y[0] = z + PIO2_2T
        y[1] = z - y[0] + PIO2_2T
      }
      return -1
    }
  }
  if ix <= 0x413921fb {
    // |x| <= 2^19 * (pi/2), medium size
    let t = x.abs()
    let n = (t * INV_PIO2 + HALF).to_int()
    let fn_ = n.to_double()
    let mut r = t - fn_ * PIO2_1
    let mut w = fn_ * PIO2_1T
    if n < 32 && ix != npio2_hw[n - 1] {
      y[0] = r - w
    } else {
      let j = ix >> 20
      y[0] = r - w
      let i = j - ((get_high_word(y[0]) >> 20).reinterpret_as_int() & 0x7ff)
      if i > 16 {
        // 2nd iteration needed, good to 118 bits
        let t = r
        w = fn_ * PIO2_2
        r = t - w
        w = fn_ * PIO2_2T - (t - r - w)
        y[0] = r - w
        let i = j - ((get_high_word(y[0]) >> 20).reinterpret_as_int() & 0x7ff)
        if i > 49 {
          // 3rd iteration needed, 151 bits accuracy
          let t = r
          w = fn_ * PIO2_3
          r = t - w
          w = fn_ * PIO2_3T - (t - r - w)
          y[0] = r - w
        }
      }
    }
    y[1] = r - y[0] - w
    if hx > 0 {
      return n
    } else {
      y[0] = -y[0]
      y[1] = -y[1]
      return -n
    }
  }

  // All other (large) arguments
  if ix >= 0x7ff00000 {
    // x is inf or NaN
    y[0] = x - x
    y[1] = y[0]
    return 0
  }

  // Set z = @math.scalbn(|x|, ilogb(x) - 23)
  z = set_low_word(z, get_low_word(x))
  let e0 = (ix >> 20) - 1046 // e0 = ilogb(z) - 23
  z = set_high_word(z, (ix - (e0 << 20)).reinterpret_as_uint())
  let tx = [0.0, 0.0, 0.0]
  for i in 0..<2 {
    tx[i] = z.to_int().to_double()
    z = (z - tx[i]) * TWO24
  }
  tx[2] = z
  let mut nx = 3
  while tx[nx - 1] == 0.0 {
    nx -= 1
  }
  let n = __kernel_rem_pio2(tx, y, e0, nx, 2)
  if hx > 0 {
    n
  } else {
    y[0] = -y[0]
    y[1] = -y[1]
    -n
  }
}

///|
fn __kernel_rem_pio2(
  x : Array[Double],
  y : Array[Double],
  e0 : Int32,
  nx : Int32,
  prec : Int32,
) -> Int32 {
  let init_jk : ReadOnlyArray[Int32] = [2, 3, 4, 6]
  let two24 : Double = 16777216.0 // 0x41700000, 0x00000000
  let twon24 : Double = 5.96046447753906250000e-08 // 0x3E700000, 0x00000000

  // Declare variables at the beginning, as in the original C code
  let mut jz : Int32 = 0
  let mut jx : Int32 = 0
  let mut jv : Int32 = 0
  let mut jp : Int32 = 0
  let mut jk : Int32 = 0
  let mut carry : Int32 = 0
  let mut n : Int32 = 0
  let iq : Array[Int32] = Array::make(20, 0)
  let mut i : Int32 = 0
  let mut j : Int32 = 0
  let mut k : Int32 = 0
  let mut m : Int32 = 0
  let mut q0 : Int32 = 0
  let mut ih : Int32 = 0
  let mut z : Double = 0
  let mut fw : Double = 0
  let f : Array[Double] = Array::make(20, 0.0)
  let fq : Array[Double] = Array::make(20, 0.0)
  let q : Array[Double] = Array::make(20, 0.0)

  // initialize jk
  jk = init_jk[prec]
  jp = jk

  // determine jx, jv, q0, note that 3 > q0
  jx = nx - 1
  jv = (e0 - 3) / 24
  if jv < 0 {
    jv = 0
  }
  q0 = e0 - 24 * (jv + 1)

  // set up f[0] to f[jx+jk] where f[jx+jk] = ipio2[jv+jk]
  j = jv - jx
  m = jx + jk
  i = 0
  while i <= m {
    f[i] = if j < 0 { 0.0 } else { two_over_pi[j].to_double() }
    i += 1
    j += 1
  }

  // compute q[0], q[1], ... q[jk]
  i = 0
  while i <= jk {
    j = 0
    fw = 0.0
    while j <= jx {
      fw += x[j] * f[jx + i - j]
      j += 1
    }
    q[i] = fw
    i += 1
  }
  jz = jk

  // Use a loop to replace the `goto` logic
  let mut recompute = true
  while recompute {
    recompute = false

    // distill q[] into iq[] reversingly
    i = 0
    j = jz
    z = q[jz]
    while j > 0 {
      fw = (twon24 * z).floor()
      iq[i] = (z - two24 * fw).to_int()
      z = q[j - 1] + fw
      i += 1
      j -= 1
    }

    // compute n
    z = @math.scalbn(z, q0) // actual value of z
    z -= 8.0 * (z * 0.125).floor() // trim off integer >= 8
    n = z.to_int()
    z -= n.to_double()
    ih = 0
    if q0 > 0 {
      // need iq[jz-1] to determine n
      i = iq[jz - 1] >> (24 - q0)
      n += i
      iq[jz - 1] -= i << (24 - q0)
      ih = iq[jz - 1] >> (23 - q0)
    } else if q0 == 0 {
      ih = iq[jz - 1] >> 23
    } else if z >= 0.5 {
      ih = 2
    }
    if ih > 0 {
      // q > 0.5
      n += 1
      carry = 0
      i = 0
      while i < jz {
        j = iq[i]
        if carry == 0 {
          if j != 0 {
            carry = 1
            iq[i] = 0x1000000 - j
          }
        } else {
          iq[i] = 0xffffff - j
        }
        i += 1
      }
      if q0 > 0 {
        // rare case: chance is 1 in 12
        match q0 {
          1 => iq[jz - 1] = iq[jz - 1] & 0x7fffff
          2 => iq[jz - 1] = iq[jz - 1] & 0x3fffff
          _ => ()
        }
      }
      if ih == 2 {
        z = 1.0 - z
        if carry != 0 {
          z -= @math.scalbn(1.0, q0)
        }
      }
    }

    // check if recomputation is needed
    if z == 0.0 {
      j = 0
      i = jz - 1
      while i >= jk {
        j = j | iq[i]
        i -= 1
      }
      if j == 0 {
        // need recomputation
        k = 1
        while iq[jk - k] == 0 {
          k += 1
        }
        i = jz + 1
        while i <= jz + k {
          f[jx + i] = two_over_pi[jv + i].to_double()
          j = 0
          fw = 0.0
          while j <= jx {
            fw += x[j] * f[jx + i - j]
            j += 1
          }
          q[i] = fw
          i += 1
        }
        jz += k
        recompute = true // Continue to recompute
        continue
      }
    } // Skip the rest of the loop and recompute

    // chop off zero terms
    if z == 0.0 {
      jz -= 1
      q0 -= 24
      while iq[jz] == 0 {
        jz -= 1
        q0 -= 24
      }
    } else {
      // break z into 24-bit if necessary
      z = @math.scalbn(z, -q0)
      if z >= two24 {
        fw = (twon24 * z).floor()
        iq[jz] = (z - two24 * fw).to_int()
        jz += 1
        q0 += 24
        iq[jz] = fw.to_int()
      } else {
        iq[jz] = z.to_int()
      }
    }

    // convert integer "bit" chunk to floating-point value
    fw = @math.scalbn(1.0, q0)
    i = jz
    while i >= 0 {
      q[i] = fw * iq[i].to_double()
      fw *= twon24
      i -= 1
    }

    // compute PIo2[0,...,jp] * q[jz,...,0]
    i = jz
    while i >= 0 {
      fw = 0.0
      k = 0
      while k <= jp && k <= jz - i {
        fw += pi_over_2[k] * q[i + k]
        k += 1
      }
      fq[jz - i] = fw
      i -= 1
    }

    // compress fq[] into y[]
    match prec {
      0 => {
        fw = 0.0
        i = jz
        while i >= 0 {
          fw += fq[i]
          i -= 1
        }
        y[0] = if ih == 0 { fw } else { -fw }
      }
      1 | 2 => {
        fw = 0.0
        i = jz
        while i >= 0 {
          fw += fq[i]
          i -= 1
        }
        y[0] = if ih == 0 { fw } else { -fw }
        fw = fq[0] - fw
        i = 1
        while i <= jz {
          fw += fq[i]
          i += 1
        }
        y[1] = if ih == 0 { fw } else { -fw }
      }
      3 => {
        i = jz
        while i > 0 {
          fw = fq[i - 1] + fq[i]
          fq[i] += fq[i - 1] - fw
          fq[i - 1] = fw
          i -= 1
        }
        i = jz
        while i > 1 {
          fw = fq[i - 1] + fq[i]
          fq[i] += fq[i - 1] - fw
          fq[i - 1] = fw
          i -= 1
        }
        fw = 0.0
        i = jz
        while i >= 2 {
          fw += fq[i]
          i -= 1
        }
        if ih == 0 {
          y[0] = fq[0]
          y[1] = fq[1]
          y[2] = fw
        } else {
          y[0] = -fq[0]
          y[1] = -fq[1]
          y[2] = -fw
        }
      }
      _ => ()
    }
  }
  n & 7
}

///|
fn __kernel_sin(x : Double, y : Double, iy : Int32) -> Double {
  let s1 = -1.66666666666666324348e-01
  let s2 = 8.33333333332248946124e-03
  let s3 = -1.98412698298579493134e-04
  let s4 = 2.75573137070700676789e-06
  let s5 = -2.50507602534068634195e-08
  let s6 = 1.58969099521155010221e-10
  let mut z = 0.0
  let mut r = 0.0
  let mut v = 0.0
  let ix = get_high_word(x) & 0x7fffffff
  if ix < 0x3e400000 {
    if x.to_int() == 0 {
      return x
    }
  }
  z = x * x
  v = z * x
  r = s2 + z * (s3 + z * (s4 + z * (s5 + z * s6)))
  if iy == 0 {
    x + v * (s1 + z * r)
  } else {
    x - (z * (0.5 * y - v * r) - y - v * s1)
  }
}

///|
fn __kernel_cos(x : Double, y : Double) -> Double {
  let one = 1.00000000000000000000e+00
  let c1 = 4.16666666666666019037e-02
  let c2 = -1.38888888888741095749e-03
  let c3 = 2.48015872894767294178e-05
  let c4 = -2.75573143513906633035e-07
  let c5 = 2.08757232129817482790e-09
  let c6 = -1.13596475577881948265e-11
  let mut a = 0.0
  let mut hz = 0.0
  let mut z = 0.0
  let mut r = 0.0
  let mut qx = 0.0
  let ix = get_high_word(x) & 0x7fffffff
  if ix < 0x3e400000 {
    if x.to_int() == 0 {
      return one
    }
  }
  z = x * x
  r = z * (c1 + z * (c2 + z * (c3 + z * (c4 + z * (c5 + z * c6)))))
  if ix < 0x3fd33333 {
    return one - (0.5 * z - (z * r - x * y))
  } else {
    if ix > 0x3fe90000 {
      qx = 0.28125
    } else {
      qx = ((ix - 0x00200000).to_uint64() << 32).reinterpret_as_double()
    }
    hz = 0.5 * z - qx
    a = one - qx
    return a - (hz - (z * r - x * y))
  }
}

///|
let two_over_pi : ReadOnlyArray[Int32] = [
  0xA2F983, 0x6E4E44, 0x1529FC, 0x2757D1, 0xF534DD, 0xC0DB62, 0x95993C, 0x439041,
  0xFE5163, 0xABDEBB, 0xC561B7, 0x246E3A, 0x424DD2, 0xE00649, 0x2EEA09, 0xD1921C,
  0xFE1DEB, 0x1CB129, 0xA73EE8, 0x8235F5, 0x2EBB44, 0x84E99C, 0x7026B4, 0x5F7E41,
  0x3991D6, 0x398353, 0x39F49C, 0x845F8B, 0xBDF928, 0x3B1FF8, 0x97FFDE, 0x05980F,
  0xEF2F11, 0x8B5A0A, 0x6D1F6D, 0x367ECF, 0x27CB09, 0xB74F46, 0x3F669E, 0x5FEA2D,
  0x7527BA, 0xC7EBE5, 0xF17B3D, 0x0739F7, 0x8A5292, 0xEA6BFB, 0x5FB11F, 0x8D5D08,
  0x560330, 0x46FC7B, 0x6BABF0, 0xCFBC20, 0x9AF436, 0x1DA9E3, 0x91615E, 0xE61B08,
  0x659985, 0x5F14A0, 0x68408D, 0xFFD880, 0x4D7327, 0x310606, 0x1556CA, 0x73A8C9,
  0x60E27B, 0xC08C6B,
]

///|
let pi_over_2 : ReadOnlyArray[Double] = [
  1.57079625129699707031e+00, // 0x3FF921FB, 0x40000000 */
   7.54978941586159635335e-08, // 0x3E74442D, 0x00000000 */
   5.39030252995776476554e-15, // 0x3CF84698, 0x80000000 */
   3.28200341580791294123e-22, // 0x3B78CC51, 0x60000000 */
   1.27065575308067607349e-29, // 0x39F01B83, 0x80000000 */
   1.22933308981111328932e-36, // 0x387A2520, 0x40000000 */
   2.73370053816464559624e-44, // 0x36E38222, 0x80000000 */
   2.16741683877804819444e-51, // 0x3569F31D, 0x00000000 */
]

///|
let npio2_hw : ReadOnlyArray[Int32] = [
  0x3FF921FB, 0x400921FB, 0x4012D97C, 0x401921FB, 0x401F6A7A, 0x4022D97C, 0x4025FDBB,
  0x402921FB, 0x402C463A, 0x402F6A7A, 0x4031475C, 0x4032D97C, 0x40346B9C, 0x4035FDBB,
  0x40378FDB, 0x403921FB, 0x403AB41B, 0x403C463A, 0x403DD85A, 0x403F6A7A, 0x40407E4C,
  0x4041475C, 0x4042106C, 0x4042D97C, 0x4043A28C, 0x40446B9C, 0x404534AC, 0x4045FDBB,
  0x4046C6CB, 0x40478FDB, 0x404858EB, 0x404921FB,
]

///|
const PI_OVER_4 : Double = 0.785398163397448309616

///|
const PIO2_1 : Double = 1.5707963267341256e+00 // 0x3FF921FB, 0x54400000 */

///|
const PIO2_1T : Double = 6.0771005065061922e-11 // 0x3DD0B461, 0x1A600000 */

///|
const PIO2_2 : Double = 6.0771005063039660e-11 // 0x3DD0B461, 0x1A600000 */

///|
const PIO2_2T : Double = 2.0222662487959506e-21 // 0x3BA3198A, 0x2E037073 */

///|
const PIO2_3 : Double = 2.0222662487111665e-21 // 0x3BA3198A, 0x2E037073 */

///|
const PIO2_3T : Double = 8.4784276603688996e-32 // 0x397B839A, 0x252049C1 */

///|
const INV_PIO2 : Double = 6.3661977236758138e-01 // 0x3FE45F30, 0x6DC9C883 */

///|
const HALF : Double = 0.5

///|
const TWO24 : Double = 16777216.0 // 0x41700000, 0x00000000 */

///|
fn set_low_word(d : Double, v : UInt32) -> Double {
  let bits : UInt64 = d.reinterpret_as_uint64()
  let bits = bits & 0xFFFF_FFFF_0000_0000
  let bits = bits | v.to_uint64()
  bits.reinterpret_as_double()
}

///|
fn set_high_word(d : Double, v : UInt32) -> Double {
  let bits : UInt64 = d.reinterpret_as_uint64()
  let bits = bits & 0x0000_0000_FFFF_FFFF
  let bits = bits | (v.to_uint64() << 32)
  bits.reinterpret_as_double()
}

///|
fn get_high_word(x : Double) -> UInt32 {
  (x.reinterpret_as_uint64() >> 32).to_uint()
}

///|
fn get_low_word(x : Double) -> UInt32 {
  x.reinterpret_as_uint64().to_uint()
}
