package fswatch.tests.unit.core

@When[os == "macOS"]
import std.unittest.*
@When[os == "macOS"]
import std.unittest.testmacro.*
@When[os == "macOS"]
import std.fs.{Path, exists, Directory, remove}
@When[os == "macOS"]
import fswatch.core.{FileMonitor, MonitorConfig}
@When[os == "macOS"]
import fswatch.backends.BackendType

@When[os == "macOS"]
@Test
@Tag[UnitTest, Core, FileMonitor, MacOS]
class TestFileMonitorMacOS {
    @TestCase
    func testNativeBackendSelectionOnMacOS() {
        let tempDir = Path("temp/native-selection")
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
