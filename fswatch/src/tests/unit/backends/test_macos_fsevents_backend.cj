package fswatch.tests.unit.backends

@When[os == "macOS"]
import std.unittest.*
@When[os == "macOS"]
import std.unittest.testmacro.*
@When[os == "macOS"]
import std.fs.{Path, exists, Directory, remove}
@When[os == "macOS"]
import fswatch.backends.{BackendType, MacOSFSEventsBackend}

@When[os == "macOS"]
@Test
@Tag[UnitTest, Backend, MacOSFSEventsBackend]
class TestMacOSFSEventsBackend {
    private let testDir = Path("temp/fsevents-unit")

    @TestCase
    func testBackendConstruction() {
        let backend = MacOSFSEventsBackend(10)
        @Expect(backend.isRunning(), false)
        @Expect(backend.getBackendType().toString(), "BackendType.Native")
        @Expect(backend.getSupportedFeatures().contains("recursive_watch"), true)
        backend.cleanup()
    }

    @TestCase
    func testBackendStartStopWithWatch() {
        if (!exists(testDir)) {
            Directory.create(testDir, recursive: true)
        }

        let backend = MacOSFSEventsBackend(10)
        try {
            backend.addWatch(testDir, true)
            backend.start()
            @Expect(backend.isRunning(), true)
            @Expect(backend.getBackendType().toString(), "BackendType.Native")
            backend.stop()
            @Expect(backend.isRunning(), false)
        } finally {
            backend.cleanup()
            if (exists(testDir)) {
                remove(testDir, recursive: true)
            }
        }
    }
}
