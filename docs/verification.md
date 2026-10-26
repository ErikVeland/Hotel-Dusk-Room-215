# Reproducible verification

Run from the project root:

```sh
python3 tools/verify.py --profile fast --strict
python3 tools/verify.py --profile audio --strict
python3 tools/verify.py --profile native --strict
python3 tools/verify.py --profile reference --strict
python3 tools/verify.py --profile all --ios --strict
```

`--list` prints the current profile membership. The fast profile runs logic and
format checks. Audio exercises source recovery and native playback, including
whole-phrase PCM measurements, preparation costs and repeated backend switching.
Native covers app/session and renderer checks. Reference covers tests that depend
on recovered ROM captures or full-route checkpoints. All includes every profile.
Some test classes contain more than one kind of check; the whole class runs in
the profile with the required host or fixture dependency.

Audio and native checks require access to macOS Core Audio and Metal. A restricted
shell can fail those checks even when compilation succeeds. `--ios` also builds
the simulator application without code signing. It requires Xcode and its
simulator services.

Each run writes `report.json`, `report.md`, individual command logs and a static
story-process coverage report under `.build/verification/latest`. Use `--output`
to retain multiple runs. `--scratch-path PATH` selects an independent Swift build
directory when another development check is running. The audio profile also writes `audio-profile.json`, with
raw RMS/peak values, decoded loop bytes and preparation/switch timings. Decoded loop bytes exclude engine, sampler and decoder allocations. The report
also records the test process physical footprint before and after preparation;
that total includes the test runtime and any retained framework allocations. The first switch
prepares a backend; repeated switches can reuse the current cue's alternate.

The report counts individual test cases once, separately as passed, failed or
skipped. A failed command or failed test fails the run. Strict mode also fails
when any selected test skips, including missing-fixture skips. A successful test
command that reports no tests fails. Non-test checks such as builds and coverage
generation are recorded without claiming test-case coverage.

Use `--checkpoint-dir PATH` to supply checkpoints produced through the native
route; this sets `HOTEL_DUSK_ROUTE_CHECKPOINTS`. It does not generate missing
captures or treat component fixtures as complete-route evidence. Read skipped
case names in the report and their reasons in `swift.log`. Preserve those gaps
when reporting results. Static handler presence alone does not establish route
completion, input fidelity or matching presentation.
