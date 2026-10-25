# 更新日志

版本号遵循语义化版本。0.x 阶段公开接口可能调整，调整会写在这里。

## 0.1.0（待发布）

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
- 不含 Canvas 后端，`RoughSVG` 改为输出字符串。

### 工程

- GitHub Actions：check（不允许警告）、fmt、`moon build --target all`、`moon info` 后检查接口文件没有变化、三个后端的测试、gallery.svg 是否最新。
- 用锁定的 roughjs 4.6.6 重新生成 fixtures，确认和仓库里的完全一致。
- 在 macOS 和 Windows 上运行同样的检查（暂不阻塞）。
- 一个不阻塞的任务，用最新版 MoonBit 提前发现兼容性问题。
- 工具链固定为 0.10.16+b1a0e846e。
