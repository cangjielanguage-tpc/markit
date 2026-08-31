# showcase-demo

`showcase-demo` 是 `commandline/examples/` 的总入口。

它不是简单把所有 example 串起来，而是做成了一个可交互的菜单树：

- 首页先选大类
- 简单类目直接执行
- `Progress` 这类更复杂的功能进入二级菜单
- 每一级执行完后都会停留在当前层，方便继续看
- 可以随时返回上一级
- 也支持 `Run all examples`

## 运行

```bash
cd /usr1/markit/commandline/examples/showcase-demo
cjpm run
```

## 菜单结构

首页：

- `Output`
- `Color`
- `Progress`
- `Interactive`
- `CLI App`
- `Run all examples`
- `Exit`

`Progress` 子菜单：

- `Colored bars with text`
- `Bar only`
- `Three-stage progress`
- `InsertBefore + final error`
- `Spinner comparison`
- `Run all progress demos`
- `Back`

## 适合怎么用

- 想快速扫一遍能力：直接选 `Run all examples`
- 想按主题看：在首页选某个大类
- 想细看 progress 相关的不同写法：进入 `Progress`
- 想反复比较同一组能力：留在当前层继续选，不需要重启程序

## 平台说明

- Unix/macOS 终端下，菜单用方向键交互
- Windows 当前回退为文本输入模式，不进入 raw key mode
