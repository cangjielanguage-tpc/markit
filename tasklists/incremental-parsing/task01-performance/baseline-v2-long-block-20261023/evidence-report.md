# Task01 batch baseline evidence

Root reviewed and approved this method and the four disclosed absolute-noise values on 2026-10-23 as the selected SDK reference (Cangjie Compiler: 1.3.0-alpha.20260920003052 (cjnative)
Target: x86_64-w64-mingw32). This does not approve Task01 as a whole, prove all project compatibility, or establish candidate non-regression. A machine-generated calibration status alone is not task approval.

- Protocol: `markit-batch-baseline-v2-long-block`; mechanical calibration result: `ACCEPTED_QUIET_PROCESS_CALIBRATION`.
- Window: Task01 owner granted 90-120s quiet window: cjpm and extension regression paused; OS desktop activity not controlled; system and child CPU recorded outside parse timing
- Actual v2 acquisition lasted approximately three minutes. The original 90–120 second estimate was explicitly extended by Task01 owner after measured process duration became known; builds/tests stayed paused until completion. Original per-process timings are retained.
- SDK: Cangjie Compiler: 1.3.0-alpha.20260920003052 (cjnative)
Target: x86_64-w64-mingw32
- Minimum 1.1.0 compatibility remains unverified; no minimum version was raised.
- CPU: Intel(R) Core(TM) i7-8700 CPU @ 3.20GHz; 12 logical CPUs; physical memory 34123063296 bytes.
- Reference executable SHA256: `1cf4fc98cdc947fa17e1aa971a3e360eaf6b7d5039fd064ecb64f38d5dff7627`.
- Exact driver/input source SHA256: `b0e9d11bd5b547949e8f91ff52985eee1bbbf80208e5b1c0921e514a2ec26be9`.
- Frozen library manifest SHA256: `6217e111a5138c679c600a11a66827f4c2c54f47cca259bf38b8a5d15653d911`.
- 12 processes, 1008 parse-only samples, 17371 RSS observations; every process exit code [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0].

| Input/API | Median parse (µs) | p95 parse (µs) | Median MiB/s | Paired process-mean CI (µs) | Absolute A/A process-mean p95 (µs) |
|---|---:|---:|---:|---|---:|
| small/string | 25.467 | 36.636 | 4.494 | [-0.648, 2.181] | 4.444 |
| small/stream | 26.916 | 35.876 | 4.252 | [-0.681, 2.473] | 3.304 |
| large/string | 27783.506 | 31458.650 | 2.144 | [-975.955, 532.975] | 1864.615 |
| large/stream | 27844.144 | 31447.175 | 2.139 | [-561.208, 1361.157] | 2403.660 |

## Memory/CPU and observability

- Process peak RSS proxy range: 296435712–297467904 bytes.
- Per-process steady median working set range: 154099712–185368576 bytes.
- System busy CPU across each run: 26.38–40.60%; child CPU normalized to one logical core: 102.82–104.83%. Child runtime may use multiple threads. Background activity was observed, not eliminated.
- Memory/CPU sampling takes place outside the Cangjie parse timing. Neither process startup nor sampling is reported as parse latency.
- small/string: input 120 UTF-8 bytes; 500 parses/timed block; median reclaimed-managed-heap counter delta per parse 101646.3 bytes.
- small/stream: input 120 UTF-8 bytes; 500 parses/timed block; median reclaimed-managed-heap counter delta per parse 98697.2 bytes.
- large/string: input 62462 UTF-8 bytes; 8 parses/timed block; median reclaimed-managed-heap counter delta per parse 44046336.0 bytes.
- large/stream: input 62462 UTF-8 bytes; 8 parses/timed block; median reclaimed-managed-heap counter delta per parse 44066816.0 bytes.
- Reclaimed-managed-heap counter deltas are pressure proxies, not total allocation or native allocation. Automatic GC count is unavailable. Forced pre/post-sample GC timings remain separate.
- No renderer was invoked in the timed region. Rendering, CLI startup and production editing latency were not measured.

## Other checks and failures

- `cjc -O2 --static-std ... batch_driver.cj`: compiled the actual public-API driver successfully.
- Standalone `cjc --test -O2` for the new developer benchmark source: compiled successfully. Direct `--bench --parallel=false` executed three entries then failed during the fourth warmup with exit 3 and `F Check failed: module != nullptr`. Preserve `../benchmark-smoke-run.log`; this developer benchmark run is not a pass. Owner will check the regular cjpm-produced binary separately.
- `compare-builds.py --self-test`: 4/4 synthetic classifier branches passed; this is not a performance result.
- `generate-workloads.py`: 11/11 deterministic UTF-8/reference-hash workload checks passed; production editing adapter remains NOT_CONNECTED.
- Original short-block, interfered and cumulative-counter data are retained alongside this report; never silently discard them or use their cumulative snapshots as per-operation allocation.
- Root approved v2 methodology and the four disclosed absolute-noise values only as the current SDK reference (see `coordinator-review.json`). Every later stage still needs same-driver/same-SDK ABBA×3 comparison with the unchanged criteria. The separately obtained 1.1.0 SDK must have its own build, compatibility and performance evidence; never mix it with this 1.3 reference.
- No candidate production change was measured, so no batch non-regression claim is made. All remaining Task01 acceptance, including the formal developer benchmark entry, still needs verification.
