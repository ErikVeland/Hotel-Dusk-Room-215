# Chapter 2 payment

The walkthrough route now connects stored client-list state to Dunning's office-door conversation in the native session. Office entry and its record/desk searches are now connected. See [Office search](chapter-two-office.md).

## Route and evidence

The detailed guide's `CHP214` section and the spoiler-free Chapter 2 route place the office beside the lobby vending machine. They direct Kyle to knock, pay Dunning and enter after he leaves.

The native route leaves Room 215, crosses the upstairs corridor, descends the stairs and enters the lobby. The office connects lobby map R103 (3) to R115 (15), through door record 4.

The office image has separate targets for its panel, handle and sign. Page point `(96,160)` selects the panel and starts the knock response. The apology interrupt offers choices 20 and 21. Choice 21 is the guide's “I don't follow you.” answer.

Payment does not remove cash item 23. The original script retains it and clears door record 4's lock value. Dunning's departure returns to lobby exploration.

## Decoder correction

`R103.upv` contains four declared views, ten declared layer records and two unused trailing layer records. The file has 564 bytes. Declared data ends at byte 484.

The original loader at `0x020B4A44` locates layer data after the declared view headers. The lookup at `0x020B4A80` uses only the declared layer counts. It does not require the last referenced record to end at the file boundary.

`OriginalUpViewTable` now follows those bounds. Every referenced field still passes through `OriginalBytes`. Truncated declared records still fail. Unused trailing bytes no longer prevent lobby door inspection.

## Reference captures

All route inputs use the supplied ROM without memory writes.

| Script in `tools/reference/` | Output under `extracted/reference/` | Checkpoint |
| --- | --- | --- |
| `chapter-two-payment-approach.txt` | `chapter-two-payment-approach` | Office door after ordinary movement from the stored client list. |
| `chapter-two-payment-knock.txt` | `chapter-two-payment-knock` | Door conversation, including apology page 11. |
| `chapter-two-payment-apology.txt` | `chapter-two-payment-apology-ready` | Interrupt and both apology choices. |
| `chapter-two-payment-paid.txt` | `chapter-two-payment-paid-follow` | Choice 21 and returned lobby state. |

The consolidated approach matches the earlier exploratory approach's complete saved game state. Exploratory captures remain local under `extracted/reference`.

## Native checks

`OriginalPaymentRouteChecks` extends the existing Chapter 2 and full new-game route checks. It uses movement, door selection, dialogue advancement, interruption and choice input. It does not inject a process result or edit game state.

The route compares all 32,088 game-state bytes at the apology menu and after Dunning leaves. It also checks the retained cash item, cleared office lock and return to lobby exploration.

`OriginalUpViewTests` checks the lobby's declared views, office layer events and three touch targets. It also checks malformed tables, truncated layers and unused trailing bytes.

The final targeted run passed five tests with no failures or skips: the full new-game route and four close-up decoder tests. `git diff --check` also passed.

```sh
SNAPSHOT_DIR=/tmp/hotel-payment-final \
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
swift test --filter 'OriginalUpViewTests|LayoutSnapshotTests.testRenderRequiredDunningQuestionsAndDeliveryKnock'
```

The original reference also enters R115 through `chapter-two-office-enter.txt`. Its completed entry capture is `extracted/reference/chapter-two-office-enter-ready/room`. This establishes the next source checkpoint, not native office support.

## Remaining work

- Continue R115 search through the trapped memo and cabinet puzzles.
- Follow `CHP215` through the remaining cabinet memo and keys.
- Recover the crowbar and memo interactions from original execution.
- Check alternate payment answers and failure paths.
- Complete original character presentation, movement transitions and sound comparisons.

The full game remains incomplete. Script completion alone does not establish presentation fidelity.
