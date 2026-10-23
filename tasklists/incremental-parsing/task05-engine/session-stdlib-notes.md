# Session 子组最小 stdlib 操作笔记

读取路径：`C:\Users\Shawn\Desktop\cangjie_runtime\stdlib\libs\std\collection\array_list.cj` 与 `hash_map.cj`，仅核对本组实际调用。

- ArrayList.add（241行附近）：容量足够时写一个槽位并增加 size/version；满容量才 grow。patch drain 只调用输出规模 add。
- ArrayList.toArray（194行附近）：按 mySize 分配数组，copyTo 全部有效内容。故不能把全 patch queue 的 toArray 当 O(1) checkpoint；本组已改 immutable records roots。pending paragraph 的 toArray 仍是实际 open pending 的显式复制。
- ArrayList.remove(at)（351行附近）：复制后缀 `size-at-1` 个元素，尾删复制长度0；rollback 仅尾删新 appended scratch root children，不从头扫描 removeChild。
- HashMap.get：hash/index 后遍历 bucket 链；下标 set 调 add。state 候选重建只在显式 checkpoint/restore/sandbox 中进行，默认 store 不分配额外 factory map。
- testmacro/tag_macro.cj 的 verifyTagMacro 允许逗号分隔多个 identifier，测试使用 `@Tag[BlockEditing, SessionCheckpoint]`。

没有推断 manifest 1.2beta 与现 SDK 1.3alpha 的对应关系，没有声称 1.1 兼容通过。统一实测待 02 安排。
