# Story process coverage

Static story process coverage checks handler IDs only. It does not establish factory-resource matching, route completion, presentation fidelity, input fidelity, or optional inventory processes.

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
| 10 | 59, 61, 62, 67, 74, 75, 79, 80, 85, 86, 88, 90, 91 | None | 75, 88 |

## Missing handlers

| Process | Original references |
| --- | --- |

## Explicitly unsupported processes

| Process | Original references |
| --- | --- |
| 75 | EP10_R304 event 24 |
| 88 | EP10_R102 event 4 |

Regenerate with `python3 tools/audit_story_coverage.py`.
Unknown process outcomes must remain blocked. A fabricated success result would bypass the original puzzle and its state changes.
