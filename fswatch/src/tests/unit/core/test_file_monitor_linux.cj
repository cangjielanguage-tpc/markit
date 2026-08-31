package fswatch.tests.unit.core

@When[os == "Linux"]
import std.unittest.*
@When[os == "Linux"]
import std.unittest.testmacro.*
@When[os == "Linux"]
import std.fs.{Path, exists, Directory, remove}
@When[os == "Linux"]
import fswatch.core.{FileMonitor, MonitorConfig}
@When[os == "Linux"]
import fswatch.backends.BackendType

@When[os == "Linux"]
@Test
@Tag[UnitTest, Core, FileMonitor, Linux]
class TestFileMonitorLinux {
    @TestCase
    func testNativeBackendSelectionOnLinux() {
        let tempDir = Path("temp/native-selection-linux")
        if (!exists(tempDir)) {
            Directory.create(tempDir, recursive: true)
        }

        let config = MonitorConfig.default()
        config.backendType = BackendType.Native

        let monitor = FileMonitor(config: config)
        try {
            monitor.watch(tempDir, recursive: true)
            monitor.start()
            @Expect(monitor.getBackendType().toString(), "BackendType.Native")
            @Expect(monitor.isRunning(), true)
            monitor.stop()
        } finally {
            monitor.cleanup()
            if (exists(tempDir)) {
                remove(tempDir, recursive: true)
            }
        }
    }
}
