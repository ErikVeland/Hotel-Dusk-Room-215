# Chapter 2 Nile conversation and Rosa's questions

The native route leaves Dunning's office after taking the red box, approaches Louie and follows the detailed guide's `CHP217` and `CHP218` choices. It then asks Rosa about Jenny and December 5. The existing event runner handles these conversations; this work adds route comparisons and corrects diagonal walking.

The spoiler-free guide gives a different answer to Rosa's question about Louie. The keep-secret route below uses the detailed guide's “Yeah, I know him.” branch. The alternate “Rat out Louie.” route also passes its check. It covers both question topics, the final pager page and the return to corridor exploration. Its game state matches the original. Missed interrupts remain unchecked here.

## Original checkpoints

All scripts below are under `tools/reference`. They use ordinary touch and button input in the supplied ROM. Captures are local under `extracted/reference`.

| Scripts | Evidence |
| --- | --- |
| `chapter-two-office-after-box`, `chapter-two-office-exit-approach` | Return from the drawer to walking and leave the office. |
| `chapter-two-louie-diagonal-motion`, `chapter-two-louie-approach-motion` | Per-update movement and collision fields. |
| `chapter-two-louie-office-talk`, `chapter-two-louie-work`, `chapter-two-louie-reassure` | Approach, work answer and reassurance answer. |
| `chapter-two-louie-trust`, `chapter-two-louie-nile-interrupt`, `chapter-two-louie-nile-answer` | Trust choice, Nile interrupt and reply. |
| `chapter-two-louie-sense-interrupt`, `chapter-two-louie-sense-answer` | Second interrupt and Rosa's arrival. |
| `chapter-two-rosa-office-talk`, `chapter-two-rosa-office-interrupt`, `chapter-two-rosa-whats-wrong` | Rosa's first interrupt and question about Louie. |
| `chapter-two-rosa-know-louie`, `chapter-two-rosa-past-choice`, `chapter-two-rosa-keep-secret` | Honest answer and choice to keep Louie's past secret. |
| `chapter-two-rosa-tell-truth` | “Rat out Louie.” answer, both question topics, closing pager page and corridor return. |
| `chapter-two-rosa-shifty-talk`, `chapter-two-rosa-shifty-interrupt`, `chapter-two-rosa-pizza-story`, `chapter-two-rosa-pizza-return` | Shifty interrupt, pizza-boy story and question menu. |
| `chapter-two-rosa-jenny`, `chapter-two-rosa-december`, `chapter-two-rosa-pager` | Optional questions and departure. |

The reference runner uses raw DS coordinates. Close-up Back is `(15,77)`, puzzle Back is `(14,168)`, and map Talk is `(15,46)`. An interrupt tap can first finish revealing text. The scripts provide a separate tap where needed before advancing the conversation.

## Diagonal movement correction

`0x0202CD54` supplies a direction from the original trigonometric lookup. `0x0202CE5C` normalises it, multiplies by the integer movement speed and rounds the fixed-point product. Native walking previously used ordinary sine/cosine rounding for this product. On Louie's approach, that produced a Z step of −249 instead of the original −250. Repeated character collision amplified the position difference.

`OriginalMapExploration.update` now uses its existing recovered direction lookup for movement as well as facing. The frame captures compare every update through the first 42 diagonal steps, the following diagonal step and three westward collision checkpoints. The final position is `(22453,12288,8594)`.

The original approach records 45 emulator frames at page point `(60,70)`, followed by 40 at `(20,128)`. Touch sampling and controller scheduling produce 43 diagonal movement updates and 40 westward updates. The native route uses those update counts. Emulator frame counts must not be treated as controller update counts.

## Native checks

`OriginalNileRouteChecks` extends the ordinary office route. It selects the guide's choices by their original labels, uses the interruption control and asks keywords 11 and 12. A second check selects “Rat out Louie.”, asks both question topics and advances through the pager page. Both branches compare all 32,088 original game-state bytes. Pause prevents choice selection and dialogue advancement. The checkpoint route also compares the full saved state, including the retry checkpoint.

The continuous Chapter 2 route checks the Louie door destination, `EP2_R114` arrival and conversation directly. It skips two standalone door RAM comparisons because those captures retain different event flags; the standalone route keeps its byte comparisons.

`OriginalNileRouteTests` covers movement and the conversation from the captured office exit. The Chapter 2 checkpoint route and full new-game route also include this segment.

## Verification

On 18 October 2026, 27 targeted checks passed with no failures or skips. They cover the two Nile checks, both complete story routes, nine lobby checks, five upstairs checks and nine earlier map-conversation checks. Both story routes now end after Rosa's departure and the pager reminder. Original choice screens and the returned floor plan were inspected. `git diff --check` also passed.

On 1 November 2026, `OriginalChapterTwoRouteTests.testChapterTwoRosaLinensAndHelenGuideRoute` passed in 109 seconds. One native session continued from the final Chapter 1 review through the Chapter 2 puzzles and conversations to the Chapter 3 entry checkpoint. The test uses bitmap renderers for host-independent puzzle input; it does not verify Metal rendering or physical-device input.

On 1 November 2026, `LayoutSnapshotTests.testRenderRequiredDunningQuestionsAndDeliveryKnock` passed in 174.6 seconds. It starts from a fresh game and checks the Chapter 1 and Chapter 2 interactions. The R102 return check waits for the 20-frame room-entry heading blend before it checks the destination heading.

On 2 November 2026, all three `OriginalNileRouteTests` passed. The truthful-answer route asks both topics and advances through the closing pager page. It matches all 32,088 bytes of the original corridor-return state. The original input trace and test do not use memory writes.

There is no package script for these Swift targets. Run the focused checks through SwiftPM:

```sh
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test --filter 'OriginalNileRouteTests|OriginalLobbyExplorationTests|OriginalUpstairsTests|OriginalMapConversationTests'
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test --filter 'OriginalChapterTwoRouteTests.testChapterTwoRosaLinensAndHelenGuideRoute|LayoutSnapshotTests.testRenderRequiredDunningQuestionsAndDeliveryKnock'
```

## Remaining work

The connected Chapter 1–2 route now reaches the Chapter 3 entry. Earlier normal-input checkpoint tests continued from there through the Chapter 10 ending, as recorded in [Chapter 3 progress](chapter-three-progress.md). They predate the current source tree and do not establish current full-route solvability. Alternate branches, exhaustive movement boundary checks, original character composition, cinematic presentation, audio fidelity and physical Duo checks remain open.
