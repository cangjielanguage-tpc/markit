# cli-app-demo

演示 `commandline` 的 CLI 宏组合：

- `@CLIApp`
- `@Cmd`
- `@Opt`

## 运行

```bash
cd /usr1/markit/commandline/examples/cli-app-demo
cjpm run -- hello --name world
```

## 可尝试的命令

```bash
cjpm run -- hello --name world
cjpm run -- hello -n world
cjpm run -- hello
```

## 预期效果

- `hello --name world` 输出 `Hello, world!`
- `hello -n world` 也能正常工作
- 缺少 `--name` 时会触发必填参数校验
