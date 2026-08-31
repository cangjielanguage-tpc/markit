# fswatch

`fswatch` 是一个面向 Cangjie 的跨平台文件监听库。

## 当前后端支持

- Linux：`inotify`
- macOS：`FSEvents`
- Windows：仅 `PollingBackend`
- 其他平台：`PollingBackend`

## Windows 说明

Windows 使用 `PollingBackend`，不包含额外的 Windows native bridge 或链接依赖。

这意味着：

- `cjpm build`
- `cjpm test`
- 上层项目通过源码依赖引入 `fswatch`

都不需要再额外处理 Windows native 库或链接配置。

在 Windows 上：

- `BackendType.Auto` 会回退到 `PollingBackend`
- `BackendType.Native` 会打印 warning，然后回退到 `PollingBackend`
- `BackendType.Polling` 会直接使用 `PollingBackend`

回退时会打印：

```text
WARNING: Native backend unavailable, falling back to polling: ...
```

如果要确认当前实际使用的后端，可以在启动后调用：

```cangjie
monitor.getBackendType()
```

返回值在 Windows 上为 `BackendType.Polling`。

## 基本使用

```cangjie
import fswatch.{FileMonitor, EventType}
import std.fs.Path

main() {
    let monitor = FileMonitor()

    monitor.addEventHandler { event =>
        match (event.eventType) {
            case EventType.Created => println("created: ${event.path}")
            case EventType.Modified => println("modified: ${event.path}")
            case EventType.Deleted => println("deleted: ${event.path}")
            case _ => {}
        }
    }

    monitor.watch(Path("./watched_directory"), recursive: true)
    monitor.start()
}
```

## 后端选择

- `BackendType.Auto`：优先尝试 native，不可用时回退到 polling
- `BackendType.Native`：尝试 native，不可用时回退到 polling
- `BackendType.Polling`：始终使用 polling

## 构建

```bash
cjpm build
cjpm test
```

## 说明

- Windows 运行时使用 polling
- macOS 和 Linux 使用各自的 native 后端
