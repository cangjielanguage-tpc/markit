# stdlib 热路径选择性源码笔记

日期：2026-10-23。调查者：`task01_review`。仅作 Task 03 source rope / Task 04 tree 的实现参考；不构成 benchmark、运行时验证或任务验收。

## 来源与版本边界

- 用户提供目录：`C:\Users\Shawn\Desktop\cangjie_runtime\stdlib`，本次只读相关文件，未修改 stdlib、编译器、环境或项目源码，未运行 build/test。
- 根目录 [README.OpenSource:6](C:/Users/Shawn/Desktop/cangjie_runtime/README.OpenSource:6) 明写 `Version Number: 1.2.0-beta.rc`。本任务已知实际编译器为 `1.3.0-alpha.20260920003052`；此清单也可能陈旧，既不能据此断言全部源码版本，也不能保证它与已安装 stdlib 二进制对应。
- `git -C C:\Users\Shawn\Desktop\cangjie_runtime\stdlib rev-parse --show-toplevel`、`log -1 --format='%H%n%cs%n%s'`、`status --short` 均 exit 1：`fatal: cannot change to 'C:\Users\Shawn\Desktop\cangjie_runtime\stdlib': Permission denied`。已停止 Git 查询；没有读取 `.git` 元数据、修改权限或申请绕过。**HEAD、提交日期、源码与编译器对应关系未验证。**
- 顶层文件 LastWriteTimeUtc 为 `2026-09-08 02:03:38`，仅为文件系统时间，不能当提交或发行日期。以下结论限定于本次读取内容，不新增最低 SDK 验证工作。

## String / StringBuilder

| 操作 | 这份源码实际成本 | 精确依据 |
|---|---|---|
| `String.size`、字节索引 | size 为 UTF8 字节数，直接读 length；索引读一个字节。不是 Rune 数或 UTF16 code unit 数。 | [string.cj:196](C:/Users/Shawn/Desktop/cangjie_runtime/stdlib/libs/std/core/string.cj:196)、[string.cj:1180](C:/Users/Shawn/Desktop/cangjie_runtime/stdlib/libs/std/core/string.cj:1180) |
| `String[range]` | step 必须 1；界限和 UTF8 continuation-byte 切点检查后，构造共享 RawArray 的 view；不复制子串、不扫描整串。空串走 empty。 | [string.cj:1202](C:/Users/Shawn/Desktop/cangjie_runtime/stdlib/libs/std/core/string.cj:1202)、[sliceUnchecked:1190](C:/Users/Shawn/Desktop/cangjie_runtime/stdlib/libs/std/core/string.cj:1190)、[内部 ctor:116](C:/Users/Shawn/Desktop/cangjie_runtime/stdlib/libs/std/core/string.cj:116) |
| `String.toArray()` / `clone()` | 分配完整大小 RawArray，再复制全部 UTF8 字节。 | [string.cj:168](C:/Users/Shawn/Desktop/cangjie_runtime/stdlib/libs/std/core/string.cj:168)、[string.cj:238](C:/Users/Shawn/Desktop/cangjie_runtime/stdlib/libs/std/core/string.cj:238) |
| `String.fromUtf8(Array)` | 先全量 UTF8 验证，再 clone 字节；`fromUtf8Unchecked` 只跳过验证，仍 clone。不能靠 unsafe 版本消除复制。 | [string.cj:260](C:/Users/Shawn/Desktop/cangjie_runtime/stdlib/libs/std/core/string.cj:260)、[string.cj:271](C:/Users/Shawn/Desktop/cangjie_runtime/stdlib/libs/std/core/string.cj:271)、[checkInvalid:224](C:/Users/Shawn/Desktop/cangjie_runtime/stdlib/libs/std/core/string_common.cj:224) |
| `String.toRuneArray()` | 先计算 Rune 数，再分配 Rune 数组并逐 Rune 解码；两个遍历阶段。计数大串分支进入 native helper，未在本调查扩展其内部。 | [string.cj:152](C:/Users/Shawn/Desktop/cangjie_runtime/stdlib/libs/std/core/string.cj:152)、[utf8RuneSize:1508](C:/Users/Shawn/Desktop/cangjie_runtime/stdlib/libs/std/core/string.cj:1508) |
| `String.runes()` / `iterator()` | 创建持有 backing Array view 的迭代器，不先复制整串；Rune next 逐个解码。遍历仍线性；不能当随机 Rune/UTF16 定位索引。 | [string.cj:180](C:/Users/Shawn/Desktop/cangjie_runtime/stdlib/libs/std/core/string.cj:180)、[StringIteratorData:245](C:/Users/Shawn/Desktop/cangjie_runtime/stdlib/libs/std/core/string_common.cj:245)、[RuneIterator:264](C:/Users/Shawn/Desktop/cangjie_runtime/stdlib/libs/std/core/string_common.cj:264) |
| `String + String` | 分配合并大小 RawArray，复制左右两串；循环拼接不断增长的前缀会重复复制。`join` 先逐段累加 size，再一次分配并复制各段。 | [string.cj:1084](C:/Users/Shawn/Desktop/cangjie_runtime/stdlib/libs/std/core/string.cj:1084)、[join:1239](C:/Users/Shawn/Desktop/cangjie_runtime/stdlib/libs/std/core/string.cj:1239) |
| `StringBuilder.append(str)` | 无扩容时仅复制新增字节；扩容时再复制已有 prefix。默认容量 32；grow 约 1.5 倍并满足本次所需，reserve 也可能分配及复制。 | [string_builder.cj:39](C:/Users/Shawn/Desktop/cangjie_runtime/stdlib/libs/std/core/string_builder.cj:39)、[append:155](C:/Users/Shawn/Desktop/cangjie_runtime/stdlib/libs/std/core/string_builder.cj:155)、[reserve:344](C:/Users/Shawn/Desktop/cangjie_runtime/stdlib/libs/std/core/string_builder.cj:344)、[grow:360](C:/Users/Shawn/Desktop/cangjie_runtime/stdlib/libs/std/core/string_builder.cj:360) |
| `appendFromUtf8` / `append(Array<Rune>)` | 前者验证后复制；unchecked 仍复制。后者循环逐 Rune append；不要求先构造中间 String。 | [string_builder.cj:184](C:/Users/Shawn/Desktop/cangjie_runtime/stdlib/libs/std/core/string_builder.cj:184)、[unchecked:197](C:/Users/Shawn/Desktop/cangjie_runtime/stdlib/libs/std/core/string_builder.cj:197)、[Rune append:209](C:/Users/Shawn/Desktop/cangjie_runtime/stdlib/libs/std/core/string_builder.cj:209) |
| `StringBuilder.toString()` | `String(this.data[0..endIndex])`，经 Array range 和内部 String ctor，共享 backing、无全量字节复制。 | [string_builder.cj:116](C:/Users/Shawn/Desktop/cangjie_runtime/stdlib/libs/std/core/string_builder.cj:116)、[array.cj:208](C:/Users/Shawn/Desktop/cangjie_runtime/stdlib/libs/std/core/array.cj:208)、[string.cj:116](C:/Users/Shawn/Desktop/cangjie_runtime/stdlib/libs/std/core/string.cj:116) |

### 共享持有与可变性边界

- String 的 backing/start/length 保存在值中（[string.cj:27](C:/Users/Shawn/Desktop/cangjie_runtime/stdlib/libs/std/core/string.cj:27)）。小 String slice 和 Builder 输出会延长整个 backing 的生命周期；view 的长度小不表示占用的 backing 小。需要释放大块持有时，显式 `clone()` 会付出复制成本。
- 已读 `StringBuilder` 类公开操作（[string_builder.cj:28](C:/Users/Shawn/Desktop/cangjie_runtime/stdlib/libs/std/core/string_builder.cj:28) 至 393）为构造、只读 size/capacity、toString、append 系列、reset、reserve；没有公开 clear/set/remove 或索引写接口。这些相关方法没有显式 COW、引用计数判定或 alias 限制检查。
- **串行、合法 API 调用下的源码推导**：toString 固定已返回 String 的长度；后续 append 从 endIndex 之后写，grow/reserve 将已用 prefix 复制到新数组，reset 直接新分配数组（[reset:124](C:/Users/Shawn/Desktop/cangjie_runtime/stdlib/libs/std/core/string_builder.cj:124)）。所以这些操作不改写已返回 String 的旧 prefix；不应因为“无 COW”误报 append/reset 会破坏旧 String。
- 上述推导不是并发安全、持久数据结构复杂度或当前安装二进制一致性的保证。Builder 本身是可变类，不应作为跨版本共享的可变 rope 节点存储。`unsafe String.rawData()` 明确返回共享 Array（[string.cj:266](C:/Users/Shawn/Desktop/cangjie_runtime/stdlib/libs/std/core/string.cj:266)），不能靠它获得隔离快照；本调查不建议产品通过 unsafe 绕过字符串不可变边界。
- String range 仅检查 UTF8 scalar 边界；`"\r\n"[0..1]` 的切点不会被这些检查排除。CRLF 规则与 UTF16 surrogate 内部坐标拒绝/转换策略仍应由 source 层明确实现，不能靠 String.slice 代劳。

## Array / ArrayList / HashMap

| 操作 | 这份源码实际成本与风险 | 精确依据 |
|---|---|---|
| `Array.slice` / `Array[range]` | O(1) 共享 backing view；Array 索引 setter 写该 backing，因此修改 view 可影响原数组，无显式 COW。不能充当 detached mutable snapshot。 | [array.cj:88](C:/Users/Shawn/Desktop/cangjie_runtime/stdlib/libs/std/core/array.cj:88)、[setter:127](C:/Users/Shawn/Desktop/cangjie_runtime/stdlib/libs/std/core/array.cj:127)、[range:208](C:/Users/Shawn/Desktop/cangjie_runtime/stdlib/libs/std/core/array.cj:208) |
| `Array.clone` / `toArray` | clone 分配并复制元素；toArray 调用 clone。元素是 class 引用时只复制引用，不递归隔离 Node/metadata。 | [array.cj:273](C:/Users/Shawn/Desktop/cangjie_runtime/stdlib/libs/std/core/array.cj:273)、[array_common.cj:73](C:/Users/Shawn/Desktop/cangjie_runtime/stdlib/libs/std/core/array_common.cj:73) |
| `ArrayList.add` / grow | 默认容量 16；未满直接写，满时 grow 约 1.5 倍/至少所需并复制 mySize 元素。reserve 参数是 additional，不是总容量。 | [array_list.cj:102](C:/Users/Shawn/Desktop/cangjie_runtime/stdlib/libs/std/collection/array_list.cj:102)、[add:241](C:/Users/Shawn/Desktop/cangjie_runtime/stdlib/libs/std/collection/array_list.cj:241)、[reserve:746](C:/Users/Shawn/Desktop/cangjie_runtime/stdlib/libs/std/collection/array_list.cj:746)、[grow:1009](C:/Users/Shawn/Desktop/cangjie_runtime/stdlib/libs/std/collection/array_list.cj:1009) |
| `ArrayList.insert` / slice / toArray | insert 移动后缀，满时新数组复制；slice 经私有 ctor clone，是元素复制而非 Array 的 view；toArray 也分配复制。contains 线扫。 | [insert:288](C:/Users/Shawn/Desktop/cangjie_runtime/stdlib/libs/std/collection/array_list.cj:288)、[slice:833](C:/Users/Shawn/Desktop/cangjie_runtime/stdlib/libs/std/collection/array_list.cj:833)、[ctor:145](C:/Users/Shawn/Desktop/cangjie_runtime/stdlib/libs/std/collection/array_list.cj:145)、[toArray:194](C:/Users/Shawn/Desktop/cangjie_runtime/stdlib/libs/std/collection/array_list.cj:194)、[contains:1053](C:/Users/Shawn/Desktop/cangjie_runtime/stdlib/libs/std/collection/array_list.cj:1053) |
| `HashMap()` / capacity ctor | 默认立刻分配 buckets 16 与 entries 16 两个数组；指定 capacity 的 buckets 仍至少 16，entries 按 capacity 分配。不是延迟空 map。 | [hash_map.cj:377](C:/Users/Shawn/Desktop/cangjie_runtime/stdlib/libs/std/collection/hash_map.cj:377)、[capacity:429](C:/Users/Shawn/Desktop/cangjie_runtime/stdlib/libs/std/collection/hash_map.cj:429)、[tableSizeFor:1191](C:/Users/Shawn/Desktop/cangjie_runtime/stdlib/libs/std/collection/hash_map.cj:1191) |
| `HashMap.get` / add | 每次先 key.hashCode，再找 bucket 和碰撞链，比较存储 hash 与 key；不能保证最坏 O(1)。源码中的 get 没有 backing 数组分配；不据此保证编译器消除所有运行时分配。 | [hash_map.cj:480](C:/Users/Shawn/Desktop/cangjie_runtime/stdlib/libs/std/collection/hash_map.cj:480)、[add:506](C:/Users/Shawn/Desktop/cangjie_runtime/stdlib/libs/std/collection/hash_map.cj:506) |
| String key hashing | String 无缓存 hash 字段；每次 hashCode 直接调 wyhash。长串按 48/16 字节循环，成本随键字节数增长；不是“lookup 平均 O(1)”就免去长键扫描。 | [String fields:27](C:/Users/Shawn/Desktop/cangjie_runtime/stdlib/libs/std/core/string.cj:27)、[hashCode:249](C:/Users/Shawn/Desktop/cangjie_runtime/stdlib/libs/std/core/string.cj:249)、[wyhash:775](C:/Users/Shawn/Desktop/cangjie_runtime/stdlib/libs/std/core/hashable.cj:775) |
| HashMap resize / toArray | 约 0.75 bucket 负载阈值后双倍 buckets、扫描 entries 容量重建链，复用已存 hash；entries 满时约 1.5 倍扩容复制旧容量。toArray 分配 size 元素并扫描至找到全部有效项。 | [hash_map.cj:1150](C:/Users/Shawn/Desktop/cangjie_runtime/stdlib/libs/std/collection/hash_map.cj:1150)、[toArray:1126](C:/Users/Shawn/Desktop/cangjie_runtime/stdlib/libs/std/collection/hash_map.cj:1126) |

对产品的直接含义：rope 可用受控 String view 避免每片 UTF8 拷贝，但要管理大 backing 持有；编辑不能在每步先全文 toArray/toRuneArray 或循环拼接增长前缀。tree 中 ArrayList 中间插入/切片是复制成本，引用元素复制也不提供 typed codec 的 metadata/parent/TOC alias 隔离。大量空 metadata map 的 eager 分配是可能成本来源，是否改变产品表示应由实际热路径证据决定，不由此笔记扩大 Task 02 范围。

## 本次读取快照 SHA256

下表只固定本次参考文本；不是发行包/安装 stdlib 的一致性校验。

| 相对 `stdlib/libs/std/` 路径 | SHA256 |
|---|---|
| core/string.cj | `2f2394dde0ee52ee7610174e9ffea50887334f530896bb036a2677592b165338` |
| core/string_builder.cj | `ed5c637ffd9024121a6092a604490ede04f77ab65596d45a392428fa43a17d5f` |
| core/array.cj | `9ee078202dda0849978de2310fb5e3d053b392c8a252d77643a512f3cc0c5110` |
| core/array_common.cj | `afbde17caa16597d6543ea2f269ecbc849a7c4136ec94980ab319e17419a6d36` |
| core/hashable.cj | `f8c341bc36d6852f7c145accfc3376e252ed4df1d44a3f2c5bcddce0db739527` |
| collection/array_list.cj | `6093d8a27e212f6227952722bc56a42df9c222479c27ebd1cd7eb665b8ae208d` |
| collection/hash_map.cj | `e332106fb9d7a20f9ee711ecd52b37ff530275a2bf81efe7bbc505641c064bf2` |

验证方式：`Get-Content` 相关行段、`Select-String` 相关方法、`Get-FileHash -Algorithm SHA256`；无性能计时、无运行行为通过声明。版本身份缺口与 Git 拒绝保留；调查到此结束，不阻塞产品编译。
