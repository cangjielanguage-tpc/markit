package fswatch.backends

import fswatch.events.{FileEvent, EventType}
import std.collection.{HashMap, HashSet}
import std.fs.{Path, FileInfo, canonicalize}
import std.sync.Mutex
import std.time.DateTime

@When[os == "macOS"]
@C
struct NativeFSEvent {
    var eventType: Int32 = 0
    var flags: UInt64 = 0
    var isDirectory: Bool = false
    var path: CPointer<UInt8> = CPointer<UInt8>()
    var oldPath: CPointer<UInt8> = CPointer<UInt8>()
}

@When[os == "macOS"]
foreign {
    func fswatch_macos_create(): CPointer<Unit>
    func fswatch_macos_clear_watches(handle: CPointer<Unit>): Int32
    func fswatch_macos_add_watch(handle: CPointer<Unit>, path: CString): Int32
    func fswatch_macos_start(handle: CPointer<Unit>): Int32
    func fswatch_macos_stop(handle: CPointer<Unit>): Int32
    func fswatch_macos_poll_event(handle: CPointer<Unit>, event: CPointer<NativeFSEvent>): Int32
    func fswatch_macos_release_event(event: CPointer<NativeFSEvent>): Unit
    func fswatch_macos_last_error(handle: CPointer<Unit>): CString
    func fswatch_macos_destroy(handle: CPointer<Unit>): Unit
}

@When[os == "macOS"]
struct WatchScope {
    let targetPath: String
    let watchRoot: String
    let isDirectoryTarget: Bool
    let recursive: Bool

    init(path: Path, recursive: Bool) {
        let canonicalPath = canonicalize(path.toString()).normalize()
        let fileInfo = FileInfo(canonicalPath)
        let isDirectoryTarget = fileInfo.isDirectory()
        let rootPath = if (isDirectoryTarget) {
            canonicalPath
        } else {
            let parentPath = canonicalPath.parent
            if (parentPath.isEmpty()) {
                canonicalize(".").normalize()
            } else {
                canonicalize(parentPath.toString()).normalize()
            }
        }

        this.targetPath = canonicalPath.toString().replace("\\", "/")
        this.watchRoot = rootPath.toString().replace("\\", "/")
        this.isDirectoryTarget = isDirectoryTarget
        this.recursive = recursive && isDirectoryTarget
    }
}

@When[os == "macOS"]
public class MacOSFSEventsBackend <: AbstractMonitorBackend {
    private static let nativeEventCreated: Int32 = 1
    private static let nativeEventModified: Int32 = 2
    private static let nativeEventDeleted: Int32 = 3
    private static let nativeEventMoved: Int32 = 4
    private static let nativeEventAttributeChanged: Int32 = 5

    private let maxDepth: Int32
    private let watchScopes: HashMap<String, WatchScope> = HashMap<String, WatchScope>()
    private let receiverMutex = Mutex()
    private var nativeHandle: CPointer<Unit> = CPointer<Unit>()
    private var receiverActive: Bool = false
    private var receiverExited: Bool = true

    public init(maxDepth: Int32) {
        this.maxDepth = maxDepth
    }

    public func getBackendType(): BackendType {
        return BackendType.Native
    }

    public func getSupportedFeatures(): HashSet<String> {
        let features = HashSet<String>()
        features.add("recursive_watch")
        features.add("file_creation")
        features.add("file_modification")
        features.add("file_deletion")
        features.add("directory_creation")
        features.add("directory_deletion")
        features.add("file_move")
        features.add("attribute_change")
        return features
    }

    protected func doStart(): Unit {
        let handle = ensureNativeHandle()
        configureNativeWatches(handle)
        let result = unsafe { fswatch_macos_start(handle) }
        if (result != 0) {
            throw Exception("Failed to start macOS FSEvents backend: ${getNativeError(handle)}")
        }

        synchronized(receiverMutex) {
            receiverActive = true
            receiverExited = false
        }
        spawn {
            receiveEventsLoop(handle)
        }
    }

    protected func doStop(): Unit {
        synchronized(receiverMutex) {
            receiverActive = false
        }

        if (nativeHandle.isNotNull()) {
            let result = unsafe { fswatch_macos_stop(nativeHandle) }
            if (result != 0) {
                throw Exception("Failed to stop macOS FSEvents backend: ${getNativeError(nativeHandle)}")
            }
        }
        waitForReceiverExit()
        synchronized(receiverMutex) {
            if (nativeHandle.isNotNull()) {
                unsafe {
                    fswatch_macos_destroy(nativeHandle)
                }
                nativeHandle = CPointer<Unit>()
            }
            receiverExited = true
        }
    }

    protected func doAddWatch(path: Path, recursive: Bool): Unit {
        let scope = WatchScope(path, recursive)
        synchronized(receiverMutex) {
            watchScopes[scope.targetPath] = scope
        }
        if (isRunningFlag && nativeHandle.isNotNull()) {
            reloadNativeWatches()
        }
    }

    protected func doRemoveWatch(path: Path): Unit {
        let canonicalPath = canonicalize(path.toString()).normalize().toString().replace("\\", "/")
        synchronized(receiverMutex) {
            watchScopes.remove(canonicalPath)
        }
        if (isRunningFlag && nativeHandle.isNotNull()) {
            reloadNativeWatches()
        }
    }

    private func reloadNativeWatches(): Unit {
        synchronized(receiverMutex) {
            receiverActive = false
        }

        let handle = ensureNativeHandle()
        let stopResult = unsafe { fswatch_macos_stop(handle) }
        if (stopResult != 0) {
            throw Exception("Failed to reload macOS FSEvents backend: ${getNativeError(handle)}")
        }
        waitForReceiverExit()
        configureNativeWatches(handle)

        let startResult = unsafe { fswatch_macos_start(handle) }
        if (startResult != 0) {
            throw Exception("Failed to restart macOS FSEvents backend: ${getNativeError(handle)}")
        }

        synchronized(receiverMutex) {
            receiverActive = true
            receiverExited = false
        }
        spawn {
            receiveEventsLoop(handle)
        }
    }

    private func ensureNativeHandle(): CPointer<Unit> {
        if (nativeHandle.isNotNull()) {
            return nativeHandle
        }

        let handle = unsafe { fswatch_macos_create() }
        if (handle.isNull()) {
            throw Exception("Failed to allocate macOS FSEvents backend handle")
        }
        nativeHandle = handle
        return handle
    }

    private func configureNativeWatches(handle: CPointer<Unit>): Unit {
        let clearResult = unsafe { fswatch_macos_clear_watches(handle) }
        if (clearResult != 0) {
            throw Exception("Failed to clear macOS watch roots: ${getNativeError(handle)}")
        }

        let uniqueRoots = HashSet<String>()
        synchronized(receiverMutex) {
            for ((_, scope) in watchScopes) {
                if (uniqueRoots.contains(scope.watchRoot)) {
                    continue
                }
                uniqueRoots.add(scope.watchRoot)
                let rootCString = unsafe { LibC.mallocCString(scope.watchRoot) }
                try (resource = rootCString.asResource()) {
                    let addResult = unsafe { fswatch_macos_add_watch(handle, resource.value) }
                    if (addResult != 0) {
                        throw Exception("Failed to add macOS watch root '${scope.watchRoot}': ${getNativeError(handle)}")
                    }
                }
            }
        }
    }

    private func receiveEventsLoop(handle: CPointer<Unit>): Unit {
        try {
            while (shouldContinueReceiving()) {
                var nativeEvent = NativeFSEvent()
                let pollResult = unsafe { fswatch_macos_poll_event(handle, inout nativeEvent) }
                if (pollResult < 0) {
                    throw Exception("Failed to poll macOS filesystem events: ${getNativeError(handle)}")
                }
                if (pollResult == 0) {
                    sleep(25 * Duration.millisecond)
                    continue
                }

                try {
                    processNativeEvent(nativeEvent)
                } finally {
                    unsafe {
                        fswatch_macos_release_event(inout nativeEvent)
                    }
                }
            }
        } finally {
            synchronized(receiverMutex) {
                receiverExited = true
            }
        }
    }

    private func processNativeEvent(nativeEvent: NativeFSEvent): Unit {
        if (nativeEvent.path.isNull()) {
            return
        }

        let eventPath = CString(nativeEvent.path).toString().replace("\\", "/")
        if (!matchesAnyWatchScope(eventPath)) {
            return
        }

        let eventType = mapEventType(nativeEvent.eventType, nativeEvent.isDirectory)
        let metadata = HashMap<String, String>()
        metadata["native_backend"] = "fsevents"
        metadata["native_flags"] = nativeEvent.flags.toString()

        let oldPath = if (nativeEvent.oldPath.isNotNull()) {
            Some(Path(CString(nativeEvent.oldPath).toString()))
        } else {
            None<Path>
        }

        handleEvent(
            FileEvent(
                eventType,
                Path(eventPath),
                DateTime.now(),
                oldPath,
                metadata
            )
        )
    }

    private func shouldContinueReceiving(): Bool {
        synchronized(receiverMutex) {
            return receiverActive
        }
    }

    private func waitForReceiverExit(): Unit {
        for (_ in 0..200) {
            let exited = synchronized(receiverMutex) {
                receiverExited
            }
            if (exited) {
                return
            }
            sleep(10 * Duration.millisecond)
        }
    }

    private func matchesAnyWatchScope(path: String): Bool {
        synchronized(receiverMutex) {
            for ((_, scope) in watchScopes) {
                if (matchesScope(scope, path)) {
                    return true
                }
            }
            return false
        }
    }

    private func matchesScope(scope: WatchScope, path: String): Bool {
        if (path == scope.targetPath) {
            return true
        }

        if (!scope.isDirectoryTarget) {
            return false
        }

        let depthOpt = relativeDepth(scope.targetPath, path)
        match (depthOpt) {
            case Some(depth) =>
                if (!scope.recursive) {
                    return depth == 1
                }
                return depth <= maxDepth
            case None => return false
        }
    }

    private func relativeDepth(root: String, path: String): ?Int32 {
        let prefix = if (root == "/") { "/" } else { "${root}/" }
        if (!path.startsWith(prefix)) {
            return None<Int32>
        }

        let remainder = path[prefix.size..]
        if (remainder.isEmpty()) {
            return Some(0)
        }

        let segments = remainder.split("/")
        return Some(Int32(segments.size))
    }

    private func mapEventType(nativeEventType: Int32, isDirectory: Bool): EventType {
        if (nativeEventType == MacOSFSEventsBackend.nativeEventCreated) {
            return if (isDirectory) { EventType.DirectoryCreated } else { EventType.Created }
        }
        if (nativeEventType == MacOSFSEventsBackend.nativeEventModified) {
            return EventType.Modified
        }
        if (nativeEventType == MacOSFSEventsBackend.nativeEventDeleted) {
            return if (isDirectory) { EventType.DirectoryDeleted } else { EventType.Deleted }
        }
        if (nativeEventType == MacOSFSEventsBackend.nativeEventMoved) {
            return EventType.Moved
        }
        if (nativeEventType == MacOSFSEventsBackend.nativeEventAttributeChanged) {
            return EventType.AttributeChanged
        }
        return EventType.Other("fsevents")
    }

    private func getNativeError(handle: CPointer<Unit>): String {
        let errorCString = unsafe { fswatch_macos_last_error(handle) }
        if (errorCString.isNull()) {
            return "Unknown native backend error"
        }

        let errorText = errorCString.toString()
        if (errorText.isEmpty()) {
            return "Unknown native backend error"
        }
        return errorText
    }
}
