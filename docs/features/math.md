<a id="math"></a>
# 数学公式

Markit 的数学公式由纯仓颉实现的 `mathtex` 提供。它在构建阶段解析 TeX 数学表达式，输出 KaTeX-compatible HTML、MathML 或 Typst，让网站不需要浏览器端 KaTeX JavaScript。HTML 输出遵循 KaTeX 的 DOM 结构、class 命名和 MathML 可访问性模型。

## 引入 mathtex

`mathtex` 已发布到仓颉中心仓。独立使用数学公式渲染库时，在 `cjpm.toml` 中添加：

```toml
[dependencies]
mathtex = { version = "0.2.0" }
```

## Markdown 写法

行内公式：

```markdown
质能方程是 $E = mc^2$。
```

块级公式：

```markdown
$$
\sum_{i=1}^{n} i = \frac{n(n+1)}{2}
$$
```

在 GFM bundle 中，行内和块级数学公式会作为 Markdown 节点进入 AST，并在 HTML、Typst/PDF 等输出中走对应渲染器。

## 常用公式示例

### 行内公式

欧拉恒等式 $e^{i\pi} + 1 = 0$ 把指数、虚数、圆周率和单位元放在同一个表达式里。

梯度下降更新可以写成 $\theta_{t+1} = \theta_t - \eta \nabla_\theta L(\theta_t)$。

### 块级推导

$$
\begin{aligned}
f(x) &= ax^2 + bx + c \\
f'(x) &= 2ax + b \\
x^* &= -\frac{b}{2a}
\end{aligned}
$$

### 矩阵

$$
\begin{bmatrix}
1 & 0 & 0 \\
0 & \cos\theta & -\sin\theta \\
0 & \sin\theta & \cos\theta
\end{bmatrix}
$$

### 分段函数

$$
f(x) =
\begin{cases}
x^2, & x \ge 0 \\
-x, & x < 0
\end{cases}
$$

### 求和、积分与极限

$$
\lim_{n \to \infty} \sum_{i=1}^{n} \frac{1}{n} f\left(\frac{i}{n}\right)
= \int_0^1 f(x)\,dx
$$

### 自定义宏

$$
\newcommand{\vect}[1]{\boldsymbol{#1}}
\vect{w}^{\mathsf{T}}\vect{x} + b
$$

## 输出形态

| 输出 | 行为 |
| --- | --- |
| Website HTML | 输出 KaTeX-compatible DOM 和 MathML，可配合 KaTeX CSS 与字体显示 |
| Typst | 转换为 Typst math 表达 |
| PDF | 通过 Typst 管线进入最终 PDF |
| JSON / AST | 保留数学节点、源码和诊断信息 |

## 支持范围

`mathtex` 覆盖文档中常用的 TeX 数学表达能力：

- 上标、下标、分式、根式、括号和常见分隔符。
- 希腊字母、关系符、箭头、常见运算符和 Unicode 数学符号。
- 矩阵、cases、aligned、gathered、split、equation、array 等常用环境。
- `\left...\right`、`\middle`、`\limits`、`\nolimits`、常见 accent 和 extensible arrow。
- 简单宏定义与扩展，包括 `\def`、`\newcommand`、`\renewcommand`、`\providecommand`。

遇到不支持的长尾语法时，调用方可以按诊断结果选择显示错误、回退源码或切换兼容路径。

## Cangjie API

```cangjie
import mathtex.{MathRenderOptions, MathRenderer, MathTex}

let renderer = MathRenderer()

let html = renderer.renderHtmlAndMathMl(
    "\\sum\\limits_{i=1}^n x_i",
    options: MathRenderOptions(displayMode: true)
)

let typst = renderer.renderTypst("\\frac{a}{b}")

let parser = MathTex().createSession(displayMode: false)
parser.feed("E = ")
parser.feed("mc^2")
let parsed = parser.finalize()
```

`MathRenderResult` 会给出渲染结果、是否完全支持以及诊断信息，适合在构建器、服务端或测试中做清晰的错误处理。
