# live_server

`live_server` 是一个面向仓颉程序的轻量静态预览服务器，提供 HTTP 文件服务和带防抖的目录监听。包名为 `live_server`，源码目录为 `live-server`。

Markit CLI 使用它托管生成的网站，并在文件变更回调中触发文档构建。也可以在自己的程序中独立使用；Markdown 渲染逻辑由调用方提供。

## 从源码构建

需要仓颉 SDK 1.1.0 或更新版本。在完整仓库中执行：

```bash
git clone https://gitcode.com/Cangjie-TPC/markit.git
cd markit/live-server
cjpm build
```

本库依赖同仓库的 `commandline` 和 `fswatch`。文件监听在 Linux 上使用 inotify，在 macOS 上使用 FSEvents，Windows 使用轮询后端。Linux/macOS 的原生桥接构建需要对应平台的 C 编译工具链，具体要求见 [fswatch](../fswatch/README.md)。

## 托管静态目录

在调用方的 `cjpm.toml` 中添加源码依赖，将路径替换为本机完整仓库中的目录：

```toml
[dependencies]
live_server = { path = "/path/to/markit/live-server" }
```

准备 `dist/index.html`，在仓颉程序中启动服务：

```cangjie
import live_server.LiveServer

main() {
    let server = LiveServer("dist", "127.0.0.1", 8080)
    server.start()
}
```

打开 `http://127.0.0.1:8080/` 即可访问 `dist/index.html`。根目录路径相对于程序的当前工作目录解析，也可以传入绝对路径。

服务支持 `GET` 和 `HEAD`，目录请求读取 `index.html`，不存在的路径会尝试补全 `.html`。对于 Markit 多语言站点，如果某语言下的页面不存在且该语言首页存在，会重定向到对应语言首页。

## 监听源文件变化

在 `start()` 前注册监听路径和回调：

```cangjie
import live_server.LiveServer
import std.core.Duration

main() {
    let server = LiveServer("dist", "127.0.0.1", 8080)
    server.watch("docs", { changedFiles =>
        for (path in changedFiles) {
            println("Changed: ${path}")
        }
        // 在这里调用应用自己的构建逻辑。
    }, recursive: true, debounce: Duration.millisecond * 250)
    server.start()
}
```

回调接收一批去重后的变化路径，重命名事件会包含原路径和新路径。省略可选参数时，默认递归监听，并使用 250 毫秒的防抖时间；也可以只指定 `recursive`。

监听目录应指向输入文档，静态服务目录指向构建产物，避免构建输出再次触发源文件监听。监听回调负责触发重建；浏览器自动刷新需要由调用方的前端配合实现。

## 生命周期与接口

| 接口 | 用途 |
| --- | --- |
| `LiveServer(rootPath: String, host: String, port: Int32)` | 设置静态文件根目录、监听地址和端口 |
| `watch(path, handler)` | 注册目录监听，使用默认递归和防抖设置 |
| `watch(path, handler, recursive: ...)` | 指定是否递归监听 |
| `watch(path, handler, recursive: ..., debounce: ...)` | 同时指定递归和防抖设置 |
| `start()` | 启动监听任务和 HTTP 服务，阻塞运行服务循环 |
| `stop()` | 停止监听、释放文件监控器并关闭监听套接字 |
| `getPort()` | 返回构造时配置的端口 |

`start()` 会阻塞当前执行流程；需要程序主动停止服务时，应从其他仓颉线程或应用生命周期回调调用 `stop()`。启动异常会通过日志报告。

## 相关资料

- [LiveServer 源码](src/live_server.cj)
- [文件监听库](../fswatch/README.md)
- [Markit CLI 使用说明](../markit-cli/README.md)
- [仓库许可证](../LICENSE)
