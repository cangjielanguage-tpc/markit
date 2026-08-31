package fswatch.tests.integration

@When[os == "Linux"]
import std.unittest.*
@When[os == "Linux"]
import std.unittest.testmacro.*
@When[os == "Linux"]
import std.fs.{Path, exists, File, Directory, remove}
@When[os == "Linux"]
import std.collection.ArrayList
@When[os == "Linux"]
import std.process.execute
@When[os == "Linux"]
import fswatch.core.{FileMonitor, MonitorConfig}
@When[os == "Linux"]
import fswatch.events.{FileEvent, EventType}
@When[os == "Linux"]
import fswatch.backends.BackendType

@When[os == "Linux"]
@Test
@Tag[IntegrationTest, FileMonitoring, LinuxNative]
class TestLinuxNativeMonitoring {
    private let testDir = Path("temp/linux-native")
    private let sourceFile = Path("temp/linux-native/source.txt")
    private let movedFile = Path("temp/linux-native/renamed.txt")
    private let chmodFile = Path("temp/linux-native/attr.txt")
    private let dynamicSubDir = Path("temp/linux-native/dynamic")
    private let dynamicNestedFile = Path("temp/linux-native/dynamic/nested.txt")

    @TestCase
    func testNativeMoveEventReportsOldPath() {
        ensureCleanDirectory(testDir)
        File.writeTo(sourceFile, "move".toArray())
        if (exists(movedFile)) {
            remove(movedFile)
        }

        let monitor = newNativeMonitor()
        let receivedEvents = ArrayList<FileEvent>()
        monitor.addEventHandler({ event =>
            receivedEvents.add(event)
        })

        try {
            monitor.watch(testDir, recursive: false)
            monitor.start()
            sleep(250 * Duration.millisecond)
            receivedEvents.clear()

            let exitCode = execute("mv", [sourceFile.toString(), movedFile.toString()])
            @Expect(exitCode, 0)
            sleep(400 * Duration.millisecond)

            var hasMovedEvent = false
            for (event in receivedEvents) {
                if (event.path.toString().contains("renamed.txt")) {
                    match (event.eventType) {
                        case EventType.Moved =>
                            match (event.oldPath) {
                                case Some(oldPath) =>
                                    if (oldPath.toString().contains("source.txt")) {
                                        hasMovedEvent = true
                                    }
                                case None => ()
                            }
                        case _ => ()
                    }
                }
            }
            @Expect(hasMovedEvent, true)
        } finally {
            monitor.stop()
            monitor.cleanup()
            cleanupPath(movedFile)
            cleanupPath(sourceFile)
            cleanupPath(testDir, recursive: true)
        }
    }

    @TestCase
    func testNativeAttributeChangeEvent() {
        ensureCleanDirectory(testDir)
        File.writeTo(chmodFile, "attr".toArray())

        let monitor = newNativeMonitor()
        let receivedEvents = ArrayList<FileEvent>()
        monitor.addEventHandler({ event =>
            receivedEvents.add(event)
        })

        try {
            monitor.watch(testDir, recursive: false)
            monitor.start()
            sleep(250 * Duration.millisecond)
            receivedEvents.clear()

            let exitCode = execute("chmod", ["600", chmodFile.toString()])
            @Expect(exitCode, 0)
            sleep(400 * Duration.millisecond)

            var hasAttributeChangedEvent = false
            for (event in receivedEvents) {
                if (event.path.toString().contains("attr.txt")) {
                    match (event.eventType) {
                        case EventType.AttributeChanged => hasAttributeChangedEvent = true
                        case _ => ()
                    }
                }
            }
            @Expect(hasAttributeChangedEvent, true)
        } finally {
            monitor.stop()
            monitor.cleanup()
            cleanupPath(chmodFile)
            cleanupPath(testDir, recursive: true)
        }
    }

    @TestCase
    func testNativeRecursiveWatchTracksNewSubdirectoryChildren() {
        ensureCleanDirectory(testDir)

        let monitor = newNativeMonitor()
        let receivedEvents = ArrayList<FileEvent>()
        monitor.addEventHandler({ event =>
            receivedEvents.add(event)
        })

        try {
            monitor.watch(testDir, recursive: true)
            monitor.start()
            sleep(250 * Duration.millisecond)
            receivedEvents.clear()

            Directory.create(dynamicSubDir, recursive: true)
            sleep(300 * Duration.millisecond)
            File.writeTo(dynamicNestedFile, "nested".toArray())
            sleep(400 * Duration.millisecond)

            var hasDynamicDirectoryEvent = false
            var hasNestedFileEvent = false
            for (event in receivedEvents) {
                let pathStr = event.path.toString()
                match (event.eventType) {
                    case EventType.DirectoryCreated =>
                        if (pathStr.contains("dynamic")) {
                            hasDynamicDirectoryEvent = true
                        }
                    case EventType.Created =>
                        if (pathStr.contains("nested.txt")) {
                            hasNestedFileEvent = true
                        }
                    case _ => ()
                }
            }

            @Expect(hasDynamicDirectoryEvent, true)
            @Expect(hasNestedFileEvent, true)
        } finally {
            monitor.stop()
            monitor.cleanup()
            cleanupPath(dynamicNestedFile)
            cleanupPath(dynamicSubDir, recursive: true)
            cleanupPath(testDir, recursive: true)
        }
    }

    private func newNativeMonitor(): FileMonitor {
        let config = MonitorConfig.default()
        config.backendType = BackendType.Native
        config.enableVerboseLogging = false
        return FileMonitor(config: config)
    }

    private func ensureCleanDirectory(path: Path): Unit {
        if (exists(path)) {
            remove(path, recursive: true)
        }
        Directory.create(path, recursive: true)
    }

    private func cleanupPath(path: Path, recursive!: Bool = false): Unit {
        if (exists(path)) {
            remove(path, recursive: recursive)
        }
    }
}
