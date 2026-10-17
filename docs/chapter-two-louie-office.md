# Chapter 2 Nile conversation and Rosa's questions

The native route leaves Dunning's office after taking the red box, approaches Louie and follows the detailed guide's `CHP217` and `CHP218` choices. It then asks Rosa about Jenny and December 5. The existing event runner handles these conversations; this work adds route comparisons and corrects diagonal walking.

The spoiler-free guide offers a different answer to Rosa's question about knowing Louie. This checked route uses the detailed guide's “Yeah, I know him.” branch. Other choices and missed interrupts remain unchecked here.

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
| `chapter-two-rosa-shifty-talk`, `chapter-two-rosa-shifty-interrupt`, `chapter-two-rosa-pizza-story`, `chapter-two-rosa-pizza-return` | Shifty interrupt, pizza-boy story and question menu. |
| `chapter-two-rosa-jenny`, `chapter-two-rosa-december`, `chapter-two-rosa-pager` | Optional questions and departure. |

The reference runner uses raw DS coordinates. Close-up Back is `(15,77)`, puzzle Back is `(14,168)`, and map Talk is `(15,46)`. An interrupt tap can first finish revealing text. The scripts provide a separate tap where needed before advancing the conversation.

## Diagonal movement correction

`0x0202CD54` supplies a direction from the original trigonometric lookup. `0x0202CE5C` normalises it, multiplies by the integer movement speed and rounds the fixed-point product. Native walking previously used ordinary sine/cosine rounding for this product. On Louie's approach, that produced a Z step of −249 instead of the original −250. Repeated character collision amplified the position difference.

`OriginalMapExploration.update` now uses its existing recovered direction lookup for movement as well as facing. The frame captures compare every update through the first 42 diagonal steps, the following diagonal step and three westward collision checkpoints. The final position is `(22453,12288,8594)`.

The original approach records 45 emulator frames at page point `(60,70)`, followed by 40 at `(20,128)`. Touch sampling and controller scheduling produce 43 diagonal movement updates and 40 westward updates. The native route uses those update counts. Emulator frame counts must not be treated as controller update counts.

## Native checks

`OriginalNileRouteChecks` extends the ordinary office route. It selects the guide's choices by their original labels, uses the interruption control and asks keywords 11 and 12. Pause prevents choice selection and dialogue advancement. The checkpoint route compares all 32,088 original game-state bytes, including the retry checkpoint.

`OriginalNileRouteTests` covers movement and the conversation from the captured office exit. The Chapter 2 checkpoint route and full new-game route also include this segment.

## Verification

On 18 October 2026, 27 targeted checks passed with no failures or skips. They cover the two Nile checks, both complete story routes, nine lobby checks, five upstairs checks and nine earlier map-conversation checks. Both story routes now end after Rosa's departure and the pager reminder. Original choice screens and the returned floor plan were inspected. `git diff --check` also passed.

There is no package script for these Swift targets. Run the focused checks through SwiftPM:

```sh
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test --filter 'OriginalNileRouteTests|OriginalLobbyExplorationTests|OriginalUpstairsTests|OriginalMapConversationTests'
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test --filter 'OriginalChapterTwoRouteTests.testChapterTwoRosaLinensAndHelenGuideRoute|LayoutSnapshotTests.testRenderRequiredDunningQuestionsAndDeliveryKnock'
```

## Remaining work

Continue to Room 215 for Ed's call, then follow Dunning's directions to Louie and complete the Chapter 2 review. Alternate branches, exhaustive movement boundary checks, original character composition, cinematic presentation, audio fidelity and physical Duo checks remain open. The complete game is not yet playable.
