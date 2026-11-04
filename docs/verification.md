# Reproducible verification

Run the ordered Chapter 1-to-ending route with a new output directory:

```sh
python3 tools/verify_full_route.py --output .build/verification/full-route-001
```

This runner builds the XCTest target and runs the 80 sections listed in
`tools/full-route-tests.json` in checkpoint dependency order. It starts with an
empty checkpoint directory and stops on a failure, skip or missing test. Each
section must report exactly the requested test as passed. The final gate checks
the Chapter 3 and Chapter 10 ending saves. Logs and individual results are in
`route-report.json` beside the checkpoints. This verifies a normal-input route
with save restores between sections. Device rendering, alternate branches and
the broader test suite require separate checks.

For development, resume a stopped run with the same output directory and
`--resume`. The report records that it was resumed. After a route fix, use a new
directory for final verification from Chapter 1.

On 3 November 2026, the ordered fresh route passed all 80 sections with no
failures or skips. Both required handoff saves passed validation. The Chapter 4
stash step accepts the whole or torn memo, according to the carried inventory.

Install `tools/requirements.txt` in a Python environment, then run from the project root.
Use that environment’s Python executable for these commands:

```sh
python3 tools/verify.py --profile fast --strict
python3 tools/verify.py --profile audio --strict
python3 tools/verify.py --profile native --strict
python3 tools/verify.py --profile reference --strict --fresh-checkpoints
python3 tools/verify.py --profile all --ios --strict --fresh-checkpoints
```

`--list` prints the current profile membership. The fast profile runs logic and
format checks. Audio exercises source recovery and native playback, including
whole-phrase PCM measurements, preparation costs and repeated backend switching.
Native covers app/session and renderer checks. Reference covers tests that depend
on recovered ROM captures or full-route checkpoints. All includes every profile.
Some test classes contain more than one kind of check; the whole class runs in
the profile with the required host or fixture dependency.

The project tests use XCTest. The verifier enables XCTest discovery when the
installed SwiftPM supports it. Older SwiftPM versions use their default test
runner. Before SwiftPM compiles the test target, the verifier checks that the
selected Swift compiler can import XCTest.

On a missing XCTest import, it retries with the selected macOS platform's
developer framework directory. If the import still fails, it records a failed
Swift group with the compiler reason and continues independent checks.
This preflight does not count as a test run or route evidence.

Use the `all` profile for the clean Chapter 1-to-ending route gate. It runs the
native group first. The fresh Chapter 1 route creates `chapter3-entry` before
the reference group starts. The reference group then continues through the
later chapter handoffs. The `reference` profile alone can use a captured Chapter
1 review state, so it does not prove a fresh route from a new game.

The all profile also checks the `chapter3-entry` and `chapter10-ending` saves in
its fresh checkpoint directory. It checks each saved state checksum, state
size, chapter and map. It also checks the checksum for interaction progress in
version 2 saves. A missing, damaged or misplaced save fails the route gate even
if a test runner reports success.

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
case names in the report and their reasons in the pass logs listed in
`report.json`. Preserve those gaps when reporting results. Static handler
presence alone does not establish route
completion, input fidelity or matching presentation.

Reference and all profiles use a new, empty route-checkpoint directory by
default when `--checkpoint-dir` is not set. Use `--fresh-checkpoints` to make
that choice explicit. The directory is retained with that run's report so
generated handoffs can be reviewed. Interactive probes that require a manually
supplied starting save are excluded from release profiles. Fresh mode cannot be combined with
`--checkpoint-dir`. In strict mode, any route that still needs a missing
checkpoint fails instead of reusing a save from an earlier run. Set
`--checkpoint-dir PATH` only when you intend to reuse previously generated
route checkpoints. The reference runner repeats only tests that skipped because
a route checkpoint or earlier route step was not available. It stops when those
tests pass or the checkpoint files stop changing. It caps retries at 20 passes.
The report records the stop reason, unresolved route cases and latest status for
each test. Strict mode fails if a checkpoint-dependent test still skips.

## Puzzle solvability gate

Call a required puzzle route playable only when a clean Chapter 1 route reaches
the ending without injected puzzle results, debug selections or manually seeded
story state. Each required puzzle must complete through normal session input and
take the recovered story transition. Save and restore active puzzle state where
Continue supports it.

For screen-based and drag puzzles, route tests must use the same 192×256 touch
coordinates as the displayed puzzle. Check that those coordinates select visible
objects and can complete the puzzle. A CPU-projected route proves the process
logic; it does not prove that a player can hit the displayed object. Check touch
mapping on a supported Duo before release when source hit maps or rendered
geometry remain unresolved. Keep those results separate from the clean-route
test report.
