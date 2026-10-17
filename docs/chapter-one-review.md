# Rachel’s call and the Chapter 1 review

The native route now continues from the order documents through Rachel’s telephone call and all five Chapter 1 review questions. The Chapter 2 transition, native save decision, title and first room event are now connected. See [Chapter 2 transition and saves](chapter-two-transition.md).

Both supplied walkthroughs identify the call and review. The detailed guide uses `CHP124` and `CHP1QZ`. The original scripts, chapter table and execution captures determine the implementation.

## Connected route

1. Leave the parcel close-up and bed inspection with separate Back actions.
2. Walk past the bed towards the dresser.
3. Inspect the telephone and confirm it to call Rachel.
4. Finish the call and Kyle’s reflection.
5. Answer the five review questions.

| Stage | Original identifier |
| --- | --- |
| Telephone selection | R205 area 1, subarea 1, event 121 |
| Call and reflection on the checked route | Events 123, 124, 126 and 128 |
| Review prompts | Mode 24, events 133, 137, 141, 145 and 149 |
| Answer responses | Mode 17 |
| Correct option IDs | 61, 63, 68, 70 and 72 |
| Final requests | Kind 1, map 31; then kind 4, next chapter 1 |

Chapter values in the original state start at zero. Request value 1 therefore means Chapter 2.

## Recovered review behaviour

`OriginalChapterReview` decodes the original `.spn` chapter table. Each question provides its prompt event, next prompt and answer records. Each answer provides an event, an advance flag and optional game-flag, inventory or event-flag conditions. The decoder retains the original order.

The script catalog supplies this table to the event runner. Mode 24 builds its menu from eligible answers and the existing KIF labels. Selecting an answer enters mode 17 without pushing an ordinary-choice return frame. A wrong answer replays the current prompt. A correct answer advances the review index. These paths follow `0x0203D61C` and `0x0203CE9C`.

The final answer queues the next chapter number. Assembly at `0x0203F500`–`0x0203F520` confirms the request argument that the decompiler omitted. Chapters 1–9 have review tables. Chapter 10’s table is empty and is loaded as absent.

Original map handling at `0x0202C264` enters process 140. Search handling at `0x020340D0` also applies chapter state changes. The native host now consumes these requests and enters the save/title sequence.

## Validation

- Seventeen component checks pass, covering review answers, retries, event completion, existing event-runner behaviour and Summer’s route.
- The native route from hotel arrival through all five correct answers passes and now continues into Chapter 2.
- All 32,088 game-state bytes match at each of the five original review menus and after the first wrong-answer retry.
- Unit checks cover a wrong answer at every question, followed by the correct answer and the Chapter 2 request. Original captures for the other wrong answers remain outstanding.
- Native snapshots now include the actual choice and question controls. The first and final review menus were visually inspected. Original menu artwork, portraits and transition effects remain unfinished.

```sh
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test --filter 'OriginalChapterReviewTests|OriginalEventRunnerTests|OriginalEventCompletionTests|OriginalSummerRouteTests'
SNAPSHOT_DIR=/tmp/hotel-review-final DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test --filter LayoutSnapshotTests.testRenderRequiredDunningQuestionsAndDeliveryKnock
```

## Original checkpoints

| Local checkpoint | SHA-256 |
| --- | --- |
| `order-rachel-call/page55.mln` | `351c4f22913d56358ae9a0ed43b818af1d85613ea8999551d4f89e5258baba0c` |
| `chapter-one-review-first/page18.mln` | `23d6c6c4b0139d7e2956bfecf7e44b57c22848aa6900a0070796a492bfa0476a` |
| `chapter-one-review-second/page24.mln` | `3b0caf8d60dcfbd98af28abf65bf63bbdfe8173c5464964c0f351941bb8cd8ee` |
| `chapter-one-review-third/page20.mln` | `8ee76c50dd19c86e826d42410493e94f14085b0d35e14d6bd3c364bdcc6ff0a9` |
| `chapter-one-review-fourth/page24.mln` | `bf5ad479b666d1f91a71d85179889cefe5dcb68dcc933ac43a049910c7ef3fc0` |
| `chapter-one-review-wrong/page18.mln` | `25157e886cab2de7ea3fb0b89f8f2af16ba6de622cb3b8bd529eabe0b837afd1` |
| `chapter-one-review-final/page32.mln` | `9d6ec45589d0f8a17ec5e6554ae6bdcea9db75105d103cbab44323daa9454a32` |

The final capture has chapter value 1 and displays “Save your game?”. The `chapter-two-no-save` continuation declines that prompt and reaches the 5:30–6:00 PM chapter clock. These now have matching native state checkpoints.

Reference scripts continue the modified delivery fixture and add no memory writes. A complete matching original run from a new game remains outstanding. Native route checks use ordinary session inputs from hotel arrival.

## Next work

Continue the Chapter 2 route after Rosa’s corridor conversation. See [Rosa in Chapter 2](chapter-two-rosa.md). General midgame saves, physical Duo checks, alternate branches and presentation fidelity remain open. The full game remains unfinished.
