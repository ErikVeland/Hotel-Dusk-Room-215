# Louie's first delivery

Normal native input now takes Louie's parcel, identifies him and completes his first conversation. The route returns to Room 215.

The detailed walkthrough's `CHP111` section supplies the route. Original scripts, ARM9 handlers and recorded inputs establish the implemented behaviour.

## Connected route

The extended Chapter 1 session check starts at arrival. It completes Dunning's registration questions, Melissa's jigsaw, Jeff's conversation and the Room 215 key route. It then answers Rachel and Dunning, breaks the suitcase key, receives the knock and completes the ordinary clock transition.

Selecting **Door** starts R205 event 32. The unlocked inside door departs directly, as the original side flag specifies. The following inputs complete Louie's introduction:

| Input | Original identifier |
| --- | --- |
| Take the top parcel | Picture 5 |
| Interrupt and select `You sound familiar!` | Choice 40, event 36 |
| Select and confirm Louie's face | Picture 7 |
| Interrupt and select `Bad memories of me, eh?` | Choice 42 |
| Select `It's kind of complicated...` | Choice 44 |
| Ask about Kyle's different manner | Keyword 12 |
| Ask about Louie's street work | Keyword 10 |
| Interrupt and select `So what happened?` | Choice 46 |
| Ask what Louie will not discuss | Keyword 11 |
| Ask about the other guest's name | Keyword 13 |
| Select `I hung it up.` | Choice 48 |

The native check uses session inputs throughout. It does not inject items, puzzle results or event completion flags.

## Recovered corrections

Opcode 10, kind 5 marks every offered choice before opening the menu. The previous native runner delayed these writes until the player answered. The corrected timing matches `0x0203BC9C`, including the call to `0x02097C80`.

The question menu retains unanswered entries and appends newly available questions. `0x0203D61C` and `0x0204B728` supply this behaviour. After the street-work interrupt, keyword 13 remains above the new keyword 11. The native runner now retains this order for the current conversation.

Pictures 5 and 7 both use mode 0. The original process selects on one press and confirms on a later press. The walkthrough describes moving Louie's chin. The recorded two-press sequence succeeds without a drag.

`OriginalTouchPicture` already provides the required input and return stages. The tests compare each complete packed hit mask with original RAM. They use page coordinates `(96,155)` for the parcel and `(120,95)` for Louie's face.

The selected-mask draw uses polygon alpha 15 at `0x0200FD50` and `0x0200FE64`. The DS blend weight is `(15 + 1) / 32`. The native overlay now uses 50% opacity. This corrects the opaque silhouette found in the recognition snapshot. Foreground fade timing remains separate work.

Opcode 23 already sets Louie's person state through the recovered `0x02097E6C` handler. Recognition sets byte `0xF9` to 2. No additional identity rule was needed.

## Original comparisons

`OriginalLouieRouteTests` compares all 32,088 game-state bytes at the recorded checkpoints. It follows the conversation from event 32, including its interrupt context. It also checks both picture masks, touch confirmation, choices and question order.

The final comparison stops when event 64 marks completion. The map process later saves its live position and facing at offsets `0x08`–`0x17`. `louie-departure-boundary.txt` captures both stages. The runner comparison uses `completed`, before that map write. The full native session separately checks return to Room 215.

Reference inputs are in `tools/reference/louie-*.txt`. Captures remain local under `extracted/reference`. The corrected street-work and secret-answer runs use directories with a `2` suffix. Each input file names its output directory.

These are component comparisons. Their lineage starts with `time-transition-fixture`, which sets three completed Dunning keywords in an older Room 215 checkpoint. Subsequent Louie inputs do not modify RAM. A complete unmodified original route from Dunning's registration questions through this conversation still needs recording.

## Validation on 18 October 2026

- The final run passed 35 targeted Swift checks with no failures or skips, including the complete Louie departure comparison.
- Both full native session routes passed after that correction, including Louie's completed conversation.
- All three Louie state checks passed. They include every byte at the script-completion boundary.
- Native snapshots were inspected for the selected recognition picture and return to Room 215.
- `git diff --check` passed.

The checks use the README's `swift test` command with targeted filters. Swift cache, GPU, audio and window-server access required sandbox escalation.

## Remaining work

- The wrong parcel and notebook now have native route and original component checks. See [Wrong parcel and notebook](wrong-parcel.md).
- Melissa’s notebook conversation and puzzle-piece return now have native route and original state checks. Continue with Mila and Rosa. See [Melissa’s notebook and piece return](melissa-notebook.md).
- Compare alternate answers and missed interrupts.
- Connect original portraits, backgrounds, animations, cursor, fades and dialogue timing.
- Check physical Duo input and lifecycle behaviour.

The full game remains unfinished. A passing conversation-state comparison does not establish complete audiovisual fidelity.
