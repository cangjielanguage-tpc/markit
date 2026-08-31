package fswatch.tests.unit.backends

@When[os == "Linux"]
import std.unittest.*
@When[os == "Linux"]
import std.unittest.testmacro.*
@When[os == "Linux"]
import std.fs.{Path, exists, Directory, remove}
@When[os == "Linux"]
import fswatch.backends.{BackendType, LinuxInotifyBackend}

@When[os == "Linux"]
@Test
@Tag[UnitTest, Backend, LinuxInotifyBackend]
class TestLinuxInotifyBackend {
    private let testDir = Path("temp/inotify-unit")

    @TestCase
    func testBackendConstruction() {
        let backend = LinuxInotifyBackend(10)
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

        let backend = LinuxInotifyBackend(10)
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
