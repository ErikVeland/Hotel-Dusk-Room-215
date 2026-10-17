# Brochure and paperclip

The Chapter 1 route now reaches the brochure and collects its paperclip through ordinary native input. This follows `CHP107` in the supplied detailed walkthrough.

## Original behaviour

- Dresser area 1, subarea 4 opens view 262 from `R205.upv`.
- Search entry runs mode 10 before opening the close-up. System event 927 supplies the brochure description.
- View 262 uses `205panfbase` and the `205panf` overlay. The overlay names item 8 and event 263.
- Process 98 confirms a component with a second press. Component zero selects the background event.
- Confirmation runs mode 11. The room selector runs first. The System selector supplies event 929 after key breakage.
- Opcode 6 adds item 8 and displays its original notice. The view hides the overlay when the item's acquisition state is nonzero.
- Removing the item from inventory does not make the paperclip reappear.

Source addresses: `0x02031944` for search entry, `0x02062038` for component confirmation, `0x0203A444` for System fallback, and `0x02058A04` for layer visibility. `0x0203A444` also records the conversation block for System events.

`OriginalSearchCloseup` owns selection and layer visibility. `OriginalPlaySession` loads the original images, retains the room runner during a System response, and refreshes the image after dialogue. Views forward input to the session.

## Reference checkpoints

The `tools/reference/room215-paperclip-*.txt` scripts record ordinary original inputs. Captures remain under the ignored `extracted/reference` directory.

| Checkpoint | Save-state SHA-256 |
| --- | --- |
| `room215-paperclip-approach/inspect` | `254665d8b260d337794abc601647df0b193cacccb3e8c35e483bbaacc3537e98` |
| `room215-paperclip-brochure/closeup` | `4fda29eecb57694f08422717373b1913b3b742694795323e61e3d56ced596a72` |
| `room215-paperclip-pickup/step8` | `31a15f81e8fe7bf682af69dd4b85ea65fbdf75f663d9cbe140aeb57dfff39af1` |

The complete 32,088-byte game state matches at brochure entry and after pickup. Both composed colour buffers and packed hit maps match buffers in original RAM, before and after pickup.

On 17 October 2026, 25 targeted Swift checks passed together with no failures or skips. A separate native route check passed from arrival through pickup. It uses session input without injecting an item or puzzle result. The native before-and-after images were inspected.

## Next puzzle entry

The original inventory starts straightening before the player selects a suitcase target. `data/system/trickitem.bin` maps item 8 to trick 5, which starts process 28. The factory loads logical overlay 8, physical overlay 9. The initial original puzzle capture is `room215-paperclip-puzzle/puzzle`. Its route starts from the collected-paperclip checkpoint and uses only ordinary inventory input.

Search handler `0x02031944` and close-up handler `0x02062F08` check this table. Game flag 26 suppresses the paperclip's inventory process. Successful straightening replaces item 8 with item 9 without setting that flag. The native process and story returns have original comparisons. Inventory launch and rendering are connected, and the normal route now receives the thin wire. See [Paperclip straightening](paperclip-straightening.md).

## Remaining work

- Thin-wire lock picking and the later story are not yet connected.
- This close-up host supports layers without a second detail image or nested process. Other layouts stop explicitly.
- Close-up inventory can launch recovered item processes. Ordinary item use on close-up components, original selection markers, transitions and portraits remain incomplete.
- System fallback is connected for search modes 10–12. Other missing response paths remain explicit.
- The paperclip's earlier pickup branch and other optional inspection responses still need original route comparisons.
- Native state and bitmap checks do not establish iOS, physical Duo, accessibility or left-handed behaviour.
