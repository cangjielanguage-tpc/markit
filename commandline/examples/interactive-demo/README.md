# interactive-demo

演示 `commandline` 当前这批交互能力：

- `@Prompt`
- `@Prompt(..., secret: true)`
- `@Select`
- `@MultiSelect`
- `@SelectValue`
- `@MultiSelectValues`
- `@Confirm`
- `@RequireConfirm`

## 运行

```bash
cd /usr1/markit/commandline/examples/interactive-demo
cjpm run
```

## 交互流程

程序会依次要求你输入或选择：

1. 项目名
2. 密钥型输入
3. 模板值选择
4. 功能值选择
5. 模板索引选择
6. 功能索引选择
7. 是否确认生成
8. 最终确认
9. 通过 `interactiveForm` 再走一次值级单选

## 可尝试的输入

- `Prompt` 直接回车，验证默认值回退
- `Prompt` 输入几个字符后按退格，验证 raw-mode 编辑
- `secret Prompt` 输入时不会回显原文，只显示遮罩
- `Select` 在 Unix/macOS 真实终端里用 `↑ / ↓ + Enter`
- `MultiSelect` 在 Unix/macOS 真实终端里用 `↑ / ↓ + Space + Enter`
- `MultiSelect` 额外支持 `a` 全选、`c` 清空、`Esc` 取消
- `SelectValue / MultiSelectValues` 会直接返回值，不需要自己再拿索引映射
- 如果在 Windows、非 TTY 或测试注入场景运行，`Select` 会回退为单行输入 `2`，`MultiSelect` 会回退为单行输入 `1,3` / `1-2`
- `Confirm` 在 Unix/macOS 真实终端里可以用 `↑ / ↓ + Enter`，也可以直接按 `y / n`
- `RequireConfirm` 会在拒绝时直接抛异常，适合“执行前最后确认”
- 如果在 Windows、非 TTY 或测试注入场景运行，`Confirm` 继续接受文本输入 `y` / `n`

## 预期效果

- 会同时打印“值级结果”和“索引级结果”，方便对比两套 API
- `access token` 只展示长度，不把敏感值重新打到屏幕上
- 如果最后两次确认都通过，会输出成功信息
- 如果你在 `RequireConfirm` 那一步拒绝，程序会按异常退出，这正是它的设计用途

## 当前能验证到什么程度

- Unix CFFI backend 已经接通，方向键交互不再依赖 `stty`
- `Prompt` 已经支持 raw-mode 基础编辑和密码遮罩
- `Select / MultiSelect / Confirm` 已经是完整的 TTY 交互
- 值级 API 已经能直接用在宏和 `interactiveForm` 上
- Windows 当前默认回退为文本输入模式，不进入 raw key mode
