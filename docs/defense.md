# 答辩材料

moon_rough 是 rough.js 4.6.6 的 MoonBit 移植，目标是同样的输入和 seed 下，输出和官方逐位相同。下面按四个问题各说几句，每条后面写了在哪里能看到证据。

## 1. 为什么能做到逐位一致

rough.js 里所有"随机"都来自一个固定公式的生成器：同一个 seed 永远产生同一串数。所以输出由三件事决定：按什么顺序取数，生成器和点这些对象怎么共享，以及浮点函数算出的最后一位。三件事各有一个办法。

**随机数的调用顺序。** JavaScript 从左到右求值，一个表达式里取了几次随机数、先取哪个，都会影响后面所有数。移植时每次取随机数都单独写成一条语句，按 JS 的求值顺序排；比如 ellipse 里 `_offset(0.1, _offset(0.4, 1, o), o)`，内层的先算。fixture 里还记录了每个用例取了多少次随机数，测试先比次数，再比数值，顺序错一次就会被发现。

**对象共享语义。** rough.js 的随机数生成器懒创建在 options 对象上，`{ ...o }` 复制时已存在的会被共享，没存在的各建各的；不传 options 时，所有图形共用生成器的默认 options，随机状态跨调用延续；点也是会被原地修改的对象，hachure 填充会把多边形旋转过去再转回来，后面的步骤（cross-hatch 的第二遍）看到的是转回来后有微小变化的点。MoonBit 里带 `mut` 字段的 struct 是引用类型，复制的是指针，行为和 JS 一致，所以这些共享关系可以原样保留。

**native 后端用 fdlibm 的 sin / cos。** native 上 core 的 `sin` / `cos` 调用 C 库，约 2.5% 的参数和 V8 差 1 ulp；js 后端调宿主的 `Math`，在 arm64 上也差 1 ulp。这点差别会翻转离散判断（循环结束、`Math.round`、向上取整的计数、`toFixed`），op 的数量都可能变。所以 `src/jsmath/fdlibm.mbt` 在 js 和 native 上自带 fdlibm 的算法（V8 自己用的也是它），wasm 用 core 里同样的实现，再加上按规范精确实现的 `toFixed`、`Math.round` 和 `Math.min / max`。剩下的加减乘除和开方是 IEEE 精确运算，顺序相同结果就相同。

代码在 `src/core`、`src/hachure`、`src/jsmath`；`README.md` 的"怎么保证一致"一节有更多细节。"逐位相同"的基准是 Node 24 / x64：这就是生成 fixtures 的环境。

## 2. 测试方法

**fixture 怎么生成。** `scripts/gen_fixtures.mjs` 在 Node 里运行 `package-lock.json` 锁定的官方 roughjs 4.6.6 及它的依赖，把输入和输出写成 `.mbt` 文件，放在各个包旁边。所有预期值都来自官方的运行结果，没有手写的数。double 写成 16 位十六进制的位模式，不经过十进制，所以比的是真正的位。生成脚本包装了 `Math.imul` 和 `Math.random` 来数随机数；canvas 用一个会记录每次调用和每次属性赋值、并且禁止读取任何属性的假对象。CI 会重新生成一遍，和仓库里的比较，必须完全一致。

**比较什么。** shape 名、OpSet 类型、每个 OpSet 里 op 的类型序列、随机数调用次数，必须完全一致。坐标按 `|a − b| ≤ 1e-9 × max(1, |b|)` 比较，这个容差是保险，不是依赖：随机数顺序出错造成的偏差在 0.1 到 2 的量级，1e-9 盖不住它。实际上所有数值都是逐位相同。

**200 多万个值的误差报告。** `node scripts/error_report.mjs` 在 js、wasm-gc、native 三个后端上各跑一遍，汇总 14 个套件（底层的随机数、路径解析、曲线、hachure、三角函数，以及图形、填充、随机组合、边界情况），共比较 2,058,123 个值，三个后端的最大绝对误差都是 0，结果表在 README 的"误差报告"一节。在这之外：canvas 有 616 个 Drawable、40,147 次调用的对照，演示页和动画在 Node 里有 588 组描述、940 万个数值和 180 帧、1,739 个前缀的对照，性能测试用的 1 万个图形也有校验和。

## 3. 和 rough.js 的差异，以及为什么这样处理

原则是：正常输入输出一致，差异只出现在 API 形式上，以及 rough.js 自己会出问题的输入上。

- **`Math.random()` 可以注入。** rough.js 有三处用没有种子的 `Math.random()`（seed 为 0、dots 填充的点位置、hachure 的一个回退分支），所以官方的 dots 填充即使设了 seed 也画不出同一张图。这里交给 `RandomSource`，默认是固定种子的序列，测试可以复现；需要每次不同的，调用方自己传。
- **不修改调用方的数据。** hachure-fill 会把传进来的多边形原地旋转再转回来，用户的点会被改动最后几位。这里内部复制一份，同时在内部保留这种改动，因为后面的步骤依赖它。
- **rough.js 会死循环或抛异常的输入。** 比如起止角相同的 `arc`、`Z` 后面跟数字的路径、非法的路径字符。一个库不该卡死，所以这里要么跳过那一步，要么返回明确的错误（`NumberAfterClose`、`InvalidCharacter` 等），这些都写在 README 的差异表里，测试只检查它们能正常结束。
- **以 npm 实际加载的 bundle 为准。** `bin/` 和 bundle 里 `generator.path()` 的一处正则不一样，移植的是 Node 真正加载的那个。
- **类型收紧。** `seed` 是 32 位 `Int`，保留小数位限制在 0–100（JS 超出会抛 RangeError），`fill_style` 是枚举。
- **没有移植的：** DOM 版 `RoughSVG`（改成输出字符串）、`_curve` 的 `closePoint` 分支（4.6.6 里所有调用方传进去的都是 `null`）、roughness 小于 −1 的 path（官方会无限递归）。
- **Canvas 绑定只有 js 目标。** wasm-gc 需要宿主提供导入函数，这一轮没做；绘制逻辑写在 trait 上，所有目标都能编译。
- **浏览器里的"逐位一致"有前提。** 官方 rough.js 在浏览器里用浏览器自己的 `Math.sin / cos / tan`，最后一位可能和 fdlibm 不同。我在 Chrome 152 里试了 288 种组合，最大差 1.14e-13，没有一个像素不同。页面会如实显示是哪种情况，不写死"一致"。

## 4. 和 diago 的对接

diago 能把 D2 文本画成流程图，但它的手绘（`sketch`）选项还没实现，传进去会得到 `UnsupportedFeature`。有两条路：直接给 diago 提交代码，或者做一个独立的模块。我先在 diago 提了 issue（[#30](https://github.com/moonbit-community/diago/issues/30)），选了后者：`examples/diago_sketch` 先让 diago 照常生成 SVG，再把形状、箭头和连线的几何换成 moon_rough 的手绘线条，文字、颜色、主题和深色模式原样保留。

做成独立模块有两个原因：不需要改 diago，也不用等它的维护者回复；moon_rough 本身也不用依赖 diago 和它的一批依赖，所以它不在发布包里。实现上用的是一个只做局部替换的扫描器，不是完整的 XML 解析器，不认识的东西原样复制。输出只取决于输入、seed 和 roughness，js、wasm-gc、native 上逐字节相同，CI 逐一比对提交的 SVG。

要说清楚的限制：这个模块的输出和 D2 自己的手绘模式不是同一张图，我没有声称和它逐字节相同；如果 diago 以后自己支持 sketch，这个模块就可以去掉，issue 目前还没有回复。
