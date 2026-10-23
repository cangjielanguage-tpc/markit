# Exploratory smoke run, not an accepted calibration

The first four-process A/A run overlapped the Task01 existing-test build/runner
window. Large String and InputStream sample-pair difference intervals had
positive lower bounds. Preserve all raw data; do not use this run to freeze
performance noise or release a successor task. It predates the process-mean
calibration fields and is explicitly rejected by `compare-builds.py`.

The separately coordinated twelve-process idle-window measurement is in
`../baseline-idle-20261023/`. Its process-pair statistics, not these sample-pair
statistics, form the disclosed measurement resolution.
