# 更新日志

版本号遵循语义化版本。0.x 阶段公开接口可能调整，调整会写在这里。

## 未发布

### 新增

- `canvas` 包：rough.js 的 `RoughCanvas`。`draw(ctx, drawable)` 和 `RoughCanvas[C]` 写在 `Canvas2D` trait 上，所有目标都能编译；`JsContext` 是 js 目标上对 `CanvasRenderingContext2D` 的绑定（`extern "js"`），`Recorder` 记录调用。预期值来自官方 rough.js：616 个 Drawable、40,147 次 canvas 调用，顺序和数字都一致。wasm-gc 暂无绑定。
- 浏览器演示页 `examples/web`：左边调参数，右边并排显示 moon_rough 和官方 rough.js 4.6.6，实时对比操作序列、坐标和像素；附本地服务器、构建脚本和 Node 里的对比测试（588 组描述、940 万个数值、172 万次 canvas 调用，在 Node 24 上最大误差 0）。浏览器自己的 `Math` 函数可能让数值差到 1e-13 量级，页面会如实显示。
- `examples/diago_sketch`：给 diago 的 SVG 加手绘风格的示例模块。替换形状、箭头和连线的几何，其余原样保留；输出只取决于输入、seed 和 roughness。附同一张 D2 图的普通版和手绘版 SVG，CI 在三个后端上逐字节比对。它是独立模块，不在发布包里。

### 工程

- `.moonignore`：把本地草稿、`node_modules`、`examples/` 和演示页的 MoonBit 包排除出发布包。
- CI 新增 `web` 任务（构建演示页，跑 Node 里的对比测试，检查随页面分发的 rough.js 和 npm 包逐字节相同）和 GitHub Pages 的部署 workflow。

## 0.1.0（2026-10-25）

第一个版本，对应 rough.js 4.6.6 的 `rough.generator()` 和 SVG 输出。

### 新增

- 图形：line、rectangle、ellipse、circle、linearPath、polygon、arc（开 / 闭）、curve（单条 `curve` 和多条 `curves`）、path（SVG 路径字符串）。
- 填充：hachure、solid、zigzag、cross-hatch、dots、dashed、zigzag-line。
- 选项：`Options` 和默认值照 rough.js 4.6.6 的源码读出来，27 个字段全部支持，包括 roughness、bowing、seed、hachureAngle、hachureGap、preserveVertices、disableMultiStroke、fillShapeRoughnessGain、fixedDecimalPlaceDigits。
- 输出：和后端无关的 `Drawable`（`OpSet` 列表，op 是 `Move`、`LineTo`、`BCurveTo`），`ops_to_path`、`Generator::to_paths`，以及 `drawable_to_svg`（每个 `OpSet` 一个 `<path>`，整个 `Drawable` 一个 `<g>`）和 `svg_document`。
- 底层包，可以单独使用：`random`（rough.js 的 Random）、`path_data`（解析、绝对化、规范化、弧线转贝塞尔）、`curve`（points-on-curve、points-on-path）、`hachure`（hachure-fill）、`jsmath`（和 V8 逐位一致的 sin、cos、tan、asin、atan、`toFixed`、`Math.round` 等）。
- `RandomSource`：可以注入的 `Math.random()` 替代，seed 为 0、dots 填充和 hachure 的回退分支都用它。
- 示例 `src/examples/gallery` 和生成的 `gallery.svg`，三个后端输出的文件逐字节相同。

### 测试

- 预期值全部由 Node 调用 roughjs 4.6.6 及其依赖生成（`scripts/gen_fixtures.mjs`），以 `.mbt` 文件的形式放在各包旁边。
- 14 个对照套件，共 2,058,123 个值，js、wasm-gc、native 三个后端的最大误差都是 0。
- 覆盖底层函数、所有图形和填充的组合、600 组随机组合、边界情况，以及同一个生成器连续调用时随机数状态的延续。

### 三角函数

- sin、cos、tan、asin、atan 在 js、wasm、wasm-gc、native 上都用同一份 fdlibm 实现，不再调用宿主 Node 的 `Math`。原因是它们的最后一位在不同 V8 版本和 CPU 架构上可能不同（macOS arm64 上 `tan(1e22)` 和 x64 差 1 ulp），圆弧转贝塞尔会把这 1 ulp 放大到 1e-7。
- fixtures 里的 NaN 统一写成标准位模式，因为 NaN 的低位随 V8 版本变化。

### 与 rough.js 的差异

- rough.js 会死循环或抛异常的输入，这里会正常结束或返回错误，详见 README 的「与 rough.js 的差异」。
- 默认的 `Math.random()` 替代是固定种子的序列，每次运行起点相同。
- `RoughSVG` 改为输出字符串。0.1.0 不含 Canvas 后端，见上面「未发布」。

### 工程

- GitHub Actions：check（不允许警告）、fmt、`moon build --target all`、`moon info` 后检查接口文件没有变化、三个后端的测试、gallery.svg 是否最新。
- 用锁定的 roughjs 4.6.6 重新生成 fixtures，确认和仓库里的完全一致。
- 在 macOS 和 Windows 上运行同样的检查（暂不阻塞）。
- 一个不阻塞的任务，用最新版 MoonBit 提前发现兼容性问题。
- 工具链固定为 0.10.16+b1a0e846e。
