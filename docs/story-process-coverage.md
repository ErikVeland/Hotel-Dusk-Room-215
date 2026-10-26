# Story process coverage

Static story process coverage. Does not establish route completion, presentation fidelity, conditions, input fidelity, or optional inventory processes.

The original chapter scripts reference 47 distinct embedded processes. 23 still have no native host handler.

| Chapter | Required process IDs | Missing handlers |
| --- | --- | --- |
| 1 | 24, 25, 26, 37, 56 | None |
| 2 | 27, 30, 31, 34 | None |
| 3 | 39, 40, 41, 42, 47, 77, 84 | None |
| 4 | 48, 73 | None |
| 5 | 38, 60 | None |
| 6 | 46, 51, 53, 54, 58 | 46, 58 |
| 7 | 43, 55 | 43, 55 |
| 8 | 44, 45, 52, 76 | 44, 45, 52, 76 |
| 9 | 63, 64, 81 | 63, 64, 81 |
| 10 | 59, 61, 62, 67, 74, 75, 79, 80, 85, 86, 88, 90, 91 | 59, 61, 62, 67, 74, 75, 79, 85, 86, 88, 90, 91 |

## Missing handlers

| Process | Original references |
| --- | --- |
| 43 | EP7_R122 event 7 |
| 44 | EP8_R119 event 8 |
| 45 | EP8_R114 event 13 |
| 46 | EP6_R106 event 7 |
| 52 | EP8_R114 event 15 |
| 55 | EP7_R122 event 3 |
| 58 | EP6_R105 event 60, EP6_R105 event 90 |
| 59 | EP10_R301 event 14 |
| 61 | EP10_R302 event 8 |
| 62 | EP10_R301 event 62 |
| 63 | EP9_R116 event 4 |
| 64 | EP9_R117 event 1, EP9_R125 event 2, EP9_R205 event 2, EP9_R207 event 1, EP9_R213 event 1 |
| 67 | EP10_R301 event 64 |
| 74 | EP10_R301 event 32 |
| 75 | EP10_R304 event 24 |
| 76 | EP8_R114 event 9 |
| 79 | EP10_R304 event 22 |
| 81 | EP9_R125 event 5 |
| 85 | EP10_R305 event 53 |
| 86 | EP10_R301 event 33 |
| 88 | EP10_R102 event 4 |
| 90 | EP10_R301 event 123 |
| 91 | EP10_R301 event 34 |

Regenerate with `python3 tools/audit_story_coverage.py`.
Unknown process outcomes must remain blocked. A fabricated success result would bypass the original puzzle and its state changes.
