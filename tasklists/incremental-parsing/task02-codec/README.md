# Task02 Typed Node 重建产品模块

当前：产品代码与6个最小定向测试已落地，等待Task02 owner串行编译/运行。此处不宣称测试通过。

## 产品入口

- `markit.core.nodes.TypedNodeCodec`：由拥有具体节点类型的provider负责类型判断和浅层实例创建；额外Node引用单独枚举及恢复，避免把TOC.items强塞进children。
- `markit.core.nodes.NodeCodec`：注册provider、拒绝未知或歧义类型、重建children和额外引用、保持克隆图内部别名并分离原图mutable节点。core.nodes不导入任何插件包，没有按kind/literal降级重建。
- `Node.copyBaseTo`：ID/kind不匹配或原实例复用时拒绝；复制三类完整metadata、公共字段、真实source绑定、raw override和有效render hooks。父子链接由图重建完成。
- `Node.sharesSourceBinding`：直接验证源句柄绑定，不靠相同raw输出推断来源。
- `SessionState`恢复默认明确unsupported；旧`SessionStateSnapshot`只保留原dynamicName存储，不加入编辑专属payload/version/context字段。显式`RestorableSessionStateSnapshot`派生类持有分离payload、fingerprint和sourceVersion/context边界。

## 最小原型边界

定向测试provider用真正HeadingNode、LinkNode、TextNode、ParagraphNode、BlockquoteNode、SoftBreakNode、DocumentNode、TocNode/TocItem。它是Task02可运行原型；生产内置provider由相应插件适配任务交付，不能据此声称30插件已适配。

测试直接断言真实renderer的HTML/Markdown/Typst输出、typed字段、三类同名metadata、source/override、parent与ID、TOC额外引用及副本隔离。不依赖已冻结的Task01通用oracle设施。

本任务不实现rope、持久树或完整parse事务；保留05的真实完整事务放行门槛。公开clone操作仅用于显式重建原型/legacy桥，不加入parse(String/InputStream)热路径，也不允许未来编辑热路径每次整树clone。03/04继续按冻结接口提供局部源与树存储。

## 验证

等待统一`TypedCodecPrototype` tag编译及官方console运行。未自行启动共享cjpm target构建，未进行最低SDK兼容补充、提交或推送。
