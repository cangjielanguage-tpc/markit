package commandline_spinner_demo

import commandline.macros.{InsertBefore, Spinner, StopSpinner, Success, UpdateSpinner, Warn}
import commandline.terminal.progressLogger

main(): Int {
    @Spinner("Packaging project...")
    sleep(Duration.millisecond * 150)
    @UpdateSpinner("Packaging assets...")
    sleep(Duration.millisecond * 150)
    @InsertBefore(@Warn("Cache miss, rebuilding one module"))
    sleep(Duration.millisecond * 150)
    @StopSpinner(@Success("Package completed"))
    return 0
}
