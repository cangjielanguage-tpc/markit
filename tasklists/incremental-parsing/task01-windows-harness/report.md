# Task 01 Windows extension test harness evidence

Date: 2026-10-23. Scope: existing preview protection tests and portable test fixtures only. No production source, parser, CLI, worker, or Task 16 implementation changed.

Runtime: Node `v24.13.1`, npm `11.8.0` on the user's Windows machine.

## Changes

- `vscode-extension/test/helpers/node-cli-session.js`: loads the unchanged production `src/session.js` with a test-only `child_process.spawn` adapter. The named JavaScript fixture runs as `process.execPath fixture.js ...args`, retaining the real child process, pipes, exit status, cancellation, and ACK backpressure. Other executable names still call real spawn, including the existing nonexistent-command test. The module uses the current realm so strict object/array equality assertions retain their existing meaning.
- `vscode-extension/test/progressive-session.test.js`: stores the fixture as `fake-markit.js` and uses that adapter instead of relying on Unix shebang execution. Existing assertions remain. A new real-pipe test writes each frame one UTF-8 byte at a time and verifies Chinese/emoji text, two ordered batch IDs, exactly two ACKs, one final publication, and child cleanup.
- `heading-numbering.test.js` and all `vscode-extension/src` files are unchanged.

## Original failures and diagnosis

- Original owner-provided full baseline: 72 tests, 42 pass, 24 fail, 6 skip, exit 1. See `../task01-baseline/extension-test.log`.
- The original extensionless shebang fixture cannot be launched directly by Windows `spawn(..., {shell:false})`; errors were `ENOENT` before stream assertions could execute.
- After the Node fixture adapter, `node --test vscode-extension/test/progressive-session.test.js` from the repository root collected 25 tests: 20 pass, 5 fail, 0 skip, exit 1. All remaining failures were real `EPERM` errors from production `atomicWrite` renaming within the sandbox-provided `AC\Temp`; see `progressive-first.log`.
- An unchanged heading-only run, `node --test vscode-extension/test/heading-numbering.test.js`, collected 3 tests: 0 pass, 2 fail, 1 existing skip, exit 1. Both failures were the same sandbox temporary-directory rename restriction; see `heading-original.log`.
- No rename failure was suppressed, retried with changed privileges, replaced with non-atomic writes, or converted into a skip. Production `atomicWrite` and its assertions remain intact.

## Normal writable test directory

The root coordinator explicitly authorized setting `TEMP` and `TMP` only for the test process to a newly created, uniquely named child of:

`C:\Users\Shawn\markit\tasklists\incremental-parsing\task01-windows-harness\temp`

The script checked the resolved absolute path was inside that dedicated directory and refused to reuse an existing run directory before creating it. No system environment setting, identity, filesystem permission, or security setting changed.

- `rename-probe.log`: independent Node `fs.rename` checks for a new target and replacement target both passed; final content matched.
- `test-temp-path.txt` and `final-test-temp-path.txt`: exact per-run test temporary directories.
- Test cleanup remains the tests' existing cleanup of their own freshly generated fixtures. No user directories were reused or removed.

## Verification

All npm runs used the existing `vscode-extension/package.json` script, `node --test test/*.test.js`, from `C:\Users\Shawn\markit\vscode-extension`.

| Run | Command | Exit | Collected | Pass | Fail | Existing skip | Evidence |
| --- | --- | --- | --- | --- | --- | --- | --- |
| Existing full suite, Node adapter + workspace TEMP/TMP | `npm test` | 0 | 72 | 66 | 0 | 6 | `npm-test-workspace-temp.log` |
| Final full suite, with fragmented UTF-8 real-pipe test | `npm test` | 0 | 73 | 67 | 0 | 6 | `npm-test-final.log` |
| Production source preservation | `git diff --exit-code -- vscode-extension/src` | 0 | n/a | n/a | n/a | n/a | No diff |

The final suite includes passing real-producer ACK backpressure, cancellation, late publication suppression, timeout/disposal, malformed frame, exit-7, nonexistent-command `ENOENT`, configuration/edit serialization, background retention, document/language switching, selection/copy, edit effects, and the new byte-fragmented Unicode frame case.

The six skips predate these changes and are unchanged: five native tests require `MARKIT_TEST_BINARY`, one Chromium test requires `MARKIT_TEST_CHROMIUM`. Those integration scenarios remain unverified in this run; they are not counted as passing.

## Reproduction

From a PowerShell process in the repository root, create a new unique test temporary directory under the dedicated evidence directory after checking its absolute path containment; set that process's `TEMP` and `TMP` to it, then run `npm test` from `vscode-extension`. Do not change production `atomicWrite`, assertions, or skip conditions. The default sandbox `AC\Temp` is known to fail rename in this environment, so its failed logs remain part of the evidence.

This evidence is a Task 01 protection baseline, not proof of the new incremental parser, Task 16 worker migration, native integration, or Chromium interaction completion.
