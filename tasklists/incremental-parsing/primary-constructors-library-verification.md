# Primary constructor library regression verification

Status: Done. Owner: `/root/task04_tree`; verification only, no library product/test source changes.

The existing suites for `codehl/`, `mathtex/` and `mermaid4cj/` were compiled and executed separately from Markit. This is actual library test execution; Markit's earlier dependency compilation is not used as a substitute.

| Library | Compile exit | Native test exit | Passed | Skipped | Error | Failed |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| codehl | 0 | 0 | 74 | 0 | 0 | 0 |
| mathtex | 0 | 0 | 623 | 0 | 0 | 0 |
| mermaid4cj | 0 | 0 | 193 | 0 | 0 | 0 |
| Total | | | 890 | 0 | 0 | 0 |

## Normal commands and environment

Read each `cjpm.toml` and README first. codehl and mermaid4cj document normal `cjpm test --no-progress`; mathtex documents `cjpm test --show-tags`. All three manifests retain `compile-option = "-O2 -Woff unused"`. mathtex has no module dependencies; the other two use cached seajson.

Actual installed compiler: `1.3.0-alpha.20260920003052 (cjnative)`, target `x86_64-w64-mingw32`; CJPM `1.3.0-alpha.05`. This does not establish SDK1.1 compatibility or non-Windows behavior. Manifest SDK metadata was not changed.

For each library, from that library's project root:

```powershell
cjpm test --no-run --no-progress -j 1 --target-dir <private-target>/<library>
<private-target>/<library>/release/unittest_bin/<library>.tests.exe --no-progress --no-color --show-tags
```

Private target root: `C:/Users/Shawn/AppData/Local/Temp/markit-primary-libraries-20261023-2a97f947`. The three compilations ran serially with one compiler job. No Markit shared target was written. Generated package test executables were run directly in their standard console mode, with no tag filters, framework patches, mocked assertions or changed tests. Inventory confirms one package test executable plus the framework launcher per library; all three package executables were run. Existing tests may generate their normal ignored demo/build outputs.

## Evidence

All evidence is under [primary-library-verification](primary-library-verification):

- [summary.json](primary-library-verification/summary.json): complete counts and native exit codes.
- `*-compile-command.json` and `*-compile.log`: exact compile command, project working directory, diagnostics and exit0 marker.
- `*.tests-command.json`, `*-results.json`, `*.tests.log`: exact native command, working directory, executable SHA256, complete output and results.
- [generated-binary-inventory.json](primary-library-verification/generated-binary-inventory.json): all generated executable paths/hashes and identification of the framework launchers.
- `environment.json` / `sdk.log`: exact tool locations, SDK/platform and start time.
- `source-hashes-before.json` / `source-hashes-after.json`: all144 Cangjie source files plus six manifests/locks. All150 paths have identical before/after SHA256 and sizes.

## Diagnostics and preservation

CJPM reported that the existing seajson lock version1.4.8 conflicts with the manifest request1.5.0 and resolved the cached1.5.0 package for codehl/mermaid4cj. It automatically rewrote their ignored `cjpm.lock` files. Generated locks were archived as evidence, and the original lock bytes were restored and verified against the pre-run SHA256. No dependency source or manifest was edited. mathtex's compiler warnings about existing Unicode source characters remain in its full compile log; no warnings were hidden or repaired.

The first attempt to start a Python console wrapper hit the WindowsApps `python.exe` alias's `ResourceUnavailable` startup error before any test ran. This was not a policy denial or test failure. The same official binaries were then invoked directly through PowerShell; [startup diagnostic](primary-library-verification/python-alias-startup-diagnostic.json) records the action, target and resolution. No escalation, installation or permission bypass was used.

There are no test failures to attribute to baseline versus the constructor changes. These results establish that the current frozen library sources pass their existing Windows suites. The README's older mathtex617 count is not treated as an executed pre-change baseline; this run actually executed623 passing tests. No statistical performance or cross-platform regression claim is made, and no new testing framework or minimum-SDK work was added.
