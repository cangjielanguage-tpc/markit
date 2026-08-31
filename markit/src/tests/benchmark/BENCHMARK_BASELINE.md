# Markit v2 Benchmark Baseline

Date: 2026-05-29
Machine: local Windows development machine

## Commands

```bash
cd markit
cjpm bench --filter ParserBenchmarks

cd ../markit-legacy
cjpm bench --filter SmallDocumentBenchmarks
```

## v2 ParserBenchmarks

| Case | Median | Mean |
| --- | ---: | ---: |
| standardSmallDirectParse | 0.637 ms | 0.674 ms |
| standardGeneratedDirectParse | 38.55 ms | 38.08 ms |
| gfmMixedDirectParse | 1.436 ms | 1.489 ms |
| i18nMixedDirectParse | 1.489 ms | 1.537 ms |
| standardGeneratedIncrementalLines | 35.95 ms | 35.95 ms |
| standardGeneratedIncrementalBytes | 34.66 ms | 34.51 ms |
| gfmMixedIncrementalBytes | 2.048 ms | 2.182 ms |
| i18nMixedIncrementalLines | 1.444 ms | 1.499 ms |

## Legacy SmallDocumentBenchmarks

The legacy suite writes debug artifacts during benchmarks and uses different sample documents, so these numbers are a coarse comparison rather than an apples-to-apples parser microbenchmark.

| Case | Args | Median | Mean |
| --- | --- | ---: | ---: |
| benchmarkSmallDocumentWithLists | - | 1.887 ms | 1.913 ms |
| benchmarkSmallDocumentWithCode | - | 1.689 ms | 1.843 ms |
| benchmarkSmallDocumentMixedFormatting | - | 2.260 ms | 2.342 ms |
| benchmarkSmallDocumentWithTable | - | 2.144 ms | 2.126 ms |
| benchmarkVariableSizeSmallDocuments | 5 | 2.148 ms | 2.165 ms |
| benchmarkVariableSizeSmallDocuments | 10 | 2.864 ms | 2.806 ms |
| benchmarkVariableSizeSmallDocuments | 25 | 5.764 ms | 5.921 ms |
| benchmarkVariableSizeSmallDocuments | 50 | 10.91 ms | 10.83 ms |
| benchmarkVariableSizeSmallDocuments | 75 | 15.73 ms | 15.06 ms |
| benchmarkContentTypeVariations | headings | 1.927 ms | 2.244 ms |
| benchmarkContentTypeVariations | paragraphs | 2.892 ms | 2.880 ms |
| benchmarkContentTypeVariations | lists | 2.881 ms | 2.913 ms |
| benchmarkContentTypeVariations | code | 2.477 ms | 2.890 ms |
| benchmarkContentTypeVariations | mixed | 2.365 ms | 2.707 ms |

## Notes

- v2 adds direct, line-incremental, and byte-incremental benchmarks over the same generated document shape.
- Legacy small document numbers are retained as a historical baseline; the shared fixture section below is the stricter apples-to-apples comparison.

## v2 ParserBenchmarks Spot Check

Date: 2026-05-30

Command:

```bash
cd markit
cjpm bench --filter ParserBenchmarks
```

This run was taken after source retention and string-building cleanup work. It is recorded as a local spot check rather than replacing the baseline because several cases had high measurement error on the current machine.

| Case | Median | Mean | Err% |
| --- | ---: | ---: | ---: |
| standardSmallDirectParse | 0.784 ms | 0.839 ms | 12.5% |
| standardGeneratedDirectParse | 48.03 ms | 48.31 ms | 5.8% |
| gfmMixedDirectParse | 1.736 ms | 2.159 ms | 18.3% |
| i18nMixedDirectParse | 1.575 ms | 1.657 ms | 7.8% |
| standardGeneratedIncrementalLines | 46.63 ms | 43.88 ms | 11.4% |
| standardGeneratedIncrementalBytes | 42.67 ms | 41.46 ms | 22.5% |
| gfmMixedIncrementalBytes | 2.387 ms | 2.346 ms | 3.0% |
| i18nMixedIncrementalLines | 1.508 ms | 1.616 ms | 4.2% |

## Shared Fixture v2 vs Legacy Baseline

Date: 2026-06-01

Commands:

```bash
cd markit
cjpm bench --filter=SharedFixtureBenchmarks

cd ../markit-legacy
cjpm bench --filter=SharedFixtureBenchmarks
```

These cases use mirrored fixture generators in both projects and avoid legacy `TestHelpers` debug output. The original run below included `Markit` construction and bundle registration in each measured operation. The benchmark source was later changed to keep one parser instance per benchmark class so constructor/bundle setup is outside the measured operation; per-parse session creation is still measured.

### v2 SharedFixtureBenchmarks

| Case | Median | Mean | Err% |
| --- | ---: | ---: | ---: |
| standardSmallParseOnly | 0.705 ms | 0.730 ms | 2.2% |
| standardSmallParseAndHtml | 0.827 ms | 0.858 ms | 3.2% |
| standardGeneratedParseOnly | 46.33 ms | 46.09 ms | 5.6% |
| standardGeneratedParseAndHtml | 47.94 ms | 48.85 ms | 4.9% |
| gfmMixedParseOnly | 1.260 ms | 1.390 ms | 7.0% |
| gfmMixedParseAndHtml | 1.453 ms | 1.481 ms | 3.6% |
| gfmGeneratedParseOnly | 31.61 ms | 30.96 ms | 4.2% |
| gfmGeneratedParseAndHtml | 35.58 ms | 35.20 ms | 3.3% |
| standardGeneratedIncrementalLines | 43.57 ms | 43.74 ms | 3.5% |
| standardGeneratedIncrementalBytes64 | 45.12 ms | 45.14 ms | 7.9% |
| gfmGeneratedIncrementalBytes64 | 31.65 ms | 31.16 ms | 5.1% |

### Legacy SharedFixtureBenchmarks

| Case | Median | Mean | Err% |
| --- | ---: | ---: | ---: |
| standardSmallParseOnly | 1.009 ms | 1.088 ms | 5.2% |
| standardSmallParseAndHtml | 1.167 ms | 1.247 ms | 5.3% |
| standardGeneratedParseOnly | 73.33 ms | 77.53 ms | 11.6% |
| standardGeneratedParseAndHtml | 93.00 ms | 92.45 ms | 2.5% |
| gfmMixedParseOnly | 1.490 ms | 1.551 ms | 4.0% |
| gfmMixedParseAndHtml | 1.879 ms | 1.929 ms | 4.8% |
| gfmGeneratedParseOnly | 56.49 ms | 55.55 ms | 3.7% |
| gfmGeneratedParseAndHtml | 64.16 ms | 65.26 ms | 6.9% |

### Median Comparison

| Case | v2 Median | Legacy Median | Speedup | v2 Time Reduction |
| --- | ---: | ---: | ---: | ---: |
| standardSmallParseOnly | 0.705 ms | 1.009 ms | 1.43x | 30.1% |
| standardSmallParseAndHtml | 0.827 ms | 1.167 ms | 1.41x | 29.1% |
| standardGeneratedParseOnly | 46.33 ms | 73.33 ms | 1.58x | 36.8% |
| standardGeneratedParseAndHtml | 47.94 ms | 93.00 ms | 1.94x | 48.5% |
| gfmMixedParseOnly | 1.260 ms | 1.490 ms | 1.18x | 15.4% |
| gfmMixedParseAndHtml | 1.453 ms | 1.879 ms | 1.29x | 22.7% |
| gfmGeneratedParseOnly | 31.61 ms | 56.49 ms | 1.79x | 44.0% |
| gfmGeneratedParseAndHtml | 35.58 ms | 64.16 ms | 1.80x | 44.5% |

Summary:

- v2 is faster than legacy on all 8 shared direct parse/render cases in this constructor-included run.
- The strongest gains are large generated parse+HTML cases: Standard is 1.94x faster, GFM is 1.80x faster.
- v2 incremental feed is in the same range as direct parse for the generated fixtures: Standard line feed 43.57 ms, Standard 64-byte feed 45.12 ms, GFM 64-byte feed 31.65 ms.
- Duration and heap pressure should be read together with the memory section below.

## Shared Fixture Hot Parser Duration Spot Check

Date: 2026-06-01

This run uses parser instance fields in the benchmark class. It excludes `Markit` construction and bundle registration from each measured operation. Several duration cases had high variance on this local machine, so treat this as a spot check rather than a replacement for the stable baseline.

| Project | Case | Median | Mean | Err% |
| --- | --- | ---: | ---: | ---: |
| v2 | standardSmallParseOnly | 0.794 ms | 0.758 ms | 7.7% |
| v2 | standardSmallParseAndHtml | 0.828 ms | 0.897 ms | 6.7% |
| v2 | standardGeneratedParseOnly | 49.39 ms | 60.80 ms | 45.8% |
| v2 | standardGeneratedParseAndHtml | 101.2 ms | 113.7 ms | 15.4% |
| v2 | gfmMixedParseOnly | 2.683 ms | 2.444 ms | 14.8% |
| v2 | gfmMixedParseAndHtml | 2.231 ms | 2.638 ms | 18.0% |
| v2 | gfmGeneratedParseOnly | 66.40 ms | 65.40 ms | 12.6% |
| v2 | gfmGeneratedParseAndHtml | 67.44 ms | 65.03 ms | 13.6% |
| v2 | standardGeneratedIncrementalLines | 90.65 ms | 89.74 ms | 13.7% |
| v2 | standardGeneratedIncrementalBytes64 | 51.96 ms | 48.59 ms | 9.1% |
| v2 | gfmGeneratedIncrementalBytes64 | 34.19 ms | 34.19 ms | 4.5% |
| legacy | standardSmallParseOnly | 1.219 ms | 1.104 ms | 8.0% |
| legacy | standardSmallParseAndHtml | 1.211 ms | 1.268 ms | 3.9% |
| legacy | standardGeneratedParseOnly | 72.48 ms | 75.45 ms | 28.1% |
| legacy | standardGeneratedParseAndHtml | 103.2 ms | 110.1 ms | 16.4% |
| legacy | gfmMixedParseOnly | 1.225 ms | 1.211 ms | 2.3% |
| legacy | gfmMixedParseAndHtml | 1.528 ms | 1.531 ms | 3.3% |
| legacy | gfmGeneratedParseOnly | 51.01 ms | 51.08 ms | 5.8% |
| legacy | gfmGeneratedParseAndHtml | 63.09 ms | 65.77 ms | 11.6% |

Notes:

- Reusing a parser removes constructor/bundle registration from the operation and is a better model for normal library use.
- The high duration variance means this section should not be used for precise speedup claims yet.
- Heap pressure below was stable and is the better signal for the small-document memory question.

## Shared Fixture Heap Pressure Baseline

Date: 2026-06-01

Commands:

```bash
cd markit
cjpm bench --filter=SharedFixtureMemoryBenchmarks

cd ../markit-legacy
cjpm bench --filter=SharedFixtureMemoryBenchmarks
```

This benchmark uses `cjpm bench` with a custom `GCFreedBytes` measurement. Each benchmark class keeps one parser instance per bundle, so constructor/bundle registration is outside the measured operation. Each benchmark operation builds the parse/render result in a helper, returns only a small marker value, then explicitly runs `std.runtime.gc(heavy: true)`. The measurement reports bytes freed by GC, so it is a practical proxy for Cangjie managed-heap allocation pressure. It is not a peak RSS measurement.

### v2 SharedFixtureMemoryBenchmarks

| Case | Median | Mean | Err% |
| --- | ---: | ---: | ---: |
| standardSmallParseOnly | 336.5 KiB | 336.3 KiB | 0.2% |
| standardSmallParseAndHtml | 384.0 KiB | 385.1 KiB | 0.2% |
| standardGeneratedParseOnly | 19.43 MiB | 19.43 MiB | 0.0% |
| standardGeneratedParseAndHtml | 22.47 MiB | 22.46 MiB | 0.0% |
| gfmMixedParseOnly | 508.9 KiB | 508.8 KiB | 0.2% |
| gfmMixedParseAndHtml | 0.561 MiB | 0.560 MiB | 0.2% |
| gfmGeneratedParseOnly | 12.21 MiB | 12.21 MiB | 0.1% |
| gfmGeneratedParseAndHtml | 14.17 MiB | 14.17 MiB | 0.1% |
| standardGeneratedIncrementalLines | 22.91 MiB | 22.91 MiB | 0.0% |
| standardGeneratedIncrementalBytes64 | 20.40 MiB | 20.40 MiB | 0.0% |
| gfmGeneratedIncrementalBytes64 | 12.60 MiB | 12.60 MiB | 0.0% |

### Legacy SharedFixtureMemoryBenchmarks

| Case | Median | Mean | Err% |
| --- | ---: | ---: | ---: |
| standardSmallParseOnly | 352.7 KiB | 353.9 KiB | 0.7% |
| standardSmallParseAndHtml | 425.7 KiB | 425.7 KiB | 0.4% |
| standardGeneratedParseOnly | 23.43 MiB | 23.42 MiB | 0.0% |
| standardGeneratedParseAndHtml | 39.94 MiB | 40.47 MiB | 5.0% |
| gfmMixedParseOnly | 389.3 KiB | 389.6 KiB | 0.7% |
| gfmMixedParseAndHtml | 0.562 MiB | 0.564 MiB | 0.4% |
| gfmGeneratedParseOnly | 15.27 MiB | 15.10 MiB | 14.5% |
| gfmGeneratedParseAndHtml | 26.29 MiB | 24.54 MiB | 16.1% |

### Heap Pressure Median Comparison

| Case | v2 Median | Legacy Median | Legacy / v2 | v2 Reduction |
| --- | ---: | ---: | ---: | ---: |
| standardSmallParseOnly | 336.5 KiB | 352.7 KiB | 1.05x | 4.6% |
| standardSmallParseAndHtml | 384.0 KiB | 425.7 KiB | 1.11x | 9.8% |
| standardGeneratedParseOnly | 19.43 MiB | 23.43 MiB | 1.21x | 17.1% |
| standardGeneratedParseAndHtml | 22.47 MiB | 39.94 MiB | 1.78x | 43.7% |
| gfmMixedParseOnly | 508.9 KiB | 389.3 KiB | 0.76x | -30.7% |
| gfmMixedParseAndHtml | 0.561 MiB | 0.562 MiB | 1.00x | 0.2% |
| gfmGeneratedParseOnly | 12.21 MiB | 15.27 MiB | 1.25x | 20.0% |
| gfmGeneratedParseAndHtml | 14.17 MiB | 26.29 MiB | 1.86x | 46.1% |

Summary:

- Reusing parser instances removes constructor/bundle registration noise from the memory benchmark.
- v2 reduces managed heap pressure on 7 of 8 comparable direct parse/render cases.
- Standard small parse-only is now lower in v2 by 4.6%, which confirms the previous small-case regression was mostly benchmark setup cost.
- GFM mixed parse-only is still worse in v2 by 30.7%; this remains the next profiling target.
- Large generated parse+HTML is the strongest result: Standard uses 43.7% less freed heap, GFM uses 46.1% less.
- v2 incremental bytes feed is close to direct parse for large generated fixtures: Standard 20.40 MiB vs 19.43 MiB direct parse, GFM 12.60 MiB vs 12.21 MiB direct parse.

## Homepage Showcase Benchmark

Date: 2026-06-02

Commands:

```bash
cd markit
cjpm bench --filter=HomepageShowcaseBenchmarks
cjpm bench --filter=HomepageShowcaseMemoryBenchmarks
```

This benchmark is designed for the public homepage rather than the legacy comparison suite. The fixture is a documentation-style page with 240 sections, 1246 lines, and 33.9 KiB of UTF-8 Markdown. It contains Chinese text, emoji, tables, task lists, fenced code, math, footnotes, HTML, and i18n blocks.

### HomepageShowcaseBenchmarks

| Case | Median | Mean | Err% |
| --- | ---: | ---: | ---: |
| docsPageParseAndHtml | 80.36 ms | 80.33 ms | 3.7% |
| docsPageParseAndJson | 94.40 ms | 95.33 ms | 2.4% |
| docsPageParseAndTypst | 84.93 ms | 85.77 ms | 4.2% |
| docsPageParseAndAllOutputs | 101.1 ms | 100.2 ms | 2.8% |
| docsPageStreamingBytes64 | 88.83 ms | 88.27 ms | 1.9% |

### HomepageShowcaseMemoryBenchmarks

| Case | Median | Mean | Err% |
| --- | ---: | ---: | ---: |
| docsPageParseAndHtmlHeap | 24.43 MiB | 24.43 MiB | 0.1% |
| docsPageParseAndAllOutputsHeap | 33.49 MiB | 33.47 MiB | 0.4% |
| docsPageStreamingBytes64Heap | 26.31 MiB | 26.31 MiB | 0.0% |

Notes:

- `docsPageStreamingBytes64` feeds the 33.9 KiB fixture in 543 chunks of up to 64 bytes.
- Heap numbers use `GCFreedBytesMeasurement`, which reads `std.runtime.getGCFreedSize()` after an explicit heavy GC. They are useful for comparing managed-heap allocation pressure between changes, but they are not peak RSS, retained AST size, or end-user memory usage. Do not present these values as homepage memory footprint numbers.
