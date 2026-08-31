# progress-demo

演示 `commandline` 的进度行能力：

- `@Progress`
- `@StopProgress`
- `@InsertBefore`

## 运行

```bash
cd /usr1/markit/commandline/examples/progress-demo
cjpm run
```

## 预期效果

- 第一段：展示不同颜色的进度条，并带文字前缀
- 第二段：展示只输出进度条、不带文字的写法
- 第三段：展示三段式进度条
- 运行到中途会插入一条 `@InsertBefore(@Warn(...))`
- 每段结束后都通过 `@StopProgress(@Success(...))` 或 `@StopProgress(@Err(...))` 输出最终结果

## 这个示例重点展示什么

1. 不同颜色的进度条
2. 可以加文字，也可以不加文字
3. progress 过程中支持 `@InsertBefore(...)`
4. 支持三段式进度条
5. 支持结束时输出成功/失败结果
