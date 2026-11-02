# Story process coverage

Static process coverage checks handler IDs for chapter scripts and shared System events. It does not establish factory-resource matching, route completion, presentation fidelity, input fidelity, or optional inventory processes.

The original chapter scripts reference 47 distinct embedded processes. 0 still have no native host handler.

| Chapter | Required process IDs | Missing handlers | Explicitly unsupported |
| --- | --- | --- | --- |
| 1 | 24, 25, 26, 37, 56 | None | None |
| 2 | 27, 30, 31, 34 | None | None |
| 3 | 39, 40, 41, 42, 47, 77, 84 | None | None |
| 4 | 48, 73 | None | None |
| 5 | 38, 60 | None | None |
| 6 | 46, 51, 53, 54, 58 | None | None |
| 7 | 43, 55 | None | None |
| 8 | 44, 45, 52, 76 | None | None |
| 9 | 63, 64, 81 | None | None |
| 10 | 59, 61, 62, 67, 74, 75, 79, 80, 85, 86, 88, 90, 91 | None | None |

## Shared System processes

`System.blk` references 15 distinct embedded processes. 0 still have no native host handler.

| Process | Original references | Handler |
| --- | --- | --- |
| 29 | System event 986 | yes |
| 32 | System event 996 | yes |
| 33 | System event 990 | yes |
| 35 | System event 956 | yes |
| 50 | System event 238 | yes |
| 53 | System event 348 | yes |
| 54 | System event 351 | yes |
| 57 | System event 256 | yes |
| 58 | System event 328 | yes |
| 68 | System event 354 | yes |
| 69 | System event 357 | yes |
| 70 | System event 360 | yes |
| 71 | System event 363 | yes |
| 87 | System event 229, System event 270, System event 301, System event 320, System event 332, System event 766, System event 1183 | yes |
| 89 | System event 656 | yes |

## Missing handlers

| Process | Original references |
| --- | --- |

## Explicitly unsupported processes

| Process | Original references |
| --- | --- |

Regenerate with `python3 tools/audit_story_coverage.py`.
Unknown process outcomes must remain blocked. A fabricated success result would bypass the original puzzle and its state changes.
