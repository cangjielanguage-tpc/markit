# spinner-demo

演示 `commandline` 的 spinner 相关宏：

- `@Spinner`
- `@UpdateSpinner`
- `@InsertBefore`
- `@StopSpinner`

## 运行

```bash
cd /usr1/markit/commandline/examples/spinner-demo
cjpm run
```

## 预期效果

- 启动 spinner
- 中途更新 spinner 文案
- 临时插入一条警告，再恢复 spinner
- 最后用 `@StopSpinner(@Success(...))` 结束
