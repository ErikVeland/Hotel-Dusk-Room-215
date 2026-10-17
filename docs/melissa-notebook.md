# Melissa’s notebook and puzzle-piece return

Normal native input now continues from the wrong parcel through Melissa’s second conversation and her departure with Kevin.

Both supplied walkthroughs place this scene after the brown notebook. The detailed guide uses anchor `CHP113`. The next route is Mila and Rosa (`CHP114`). Guides select the route. Original code and matching captures establish the mechanics.

## Connected route

1. Leave the bed close-up and return to walking.
2. Approach Room 215’s door and select **Door**.
3. Walk east towards the upstairs stairway to start Melissa’s entrance.
4. Approach Melissa near Room 219, face her and select **Talk**.
5. Use both interrupts and ask the available questions.
6. Select and confirm the notebook in her hand.
7. After the reminder, talk to Melissa again.
8. Select **Items**, then **Puzzle Piece**.
9. After her response, select **Leave** to continue with Kevin and Melissa’s departure.

The native route starts at Chapter 1 arrival and uses session inputs throughout. It does not inject inventory, completion flags or process results.

| Checkpoint | Original identifier |
| --- | --- |
| Upstairs entrance | R213 region 2, event 32 |
| Conversation | Person 11, event 34 |
| First interrupt answer | Choice 31, event 40 |
| Question about her mother | Keyword 15, event 42 |
| Second interrupt answer | Choice 33, event 45 |
| Question about her father | Keyword 16, event 46 |
| Notebook selection | Picture 22 |
| Reminder to return the piece | Event 56 |
| Repeat conversation | Event 61, then question menu 41 |
| Puzzle-piece return | Item 3, mode 27, event 50 |
| Kevin and Melissa’s departure | Event 55, then event 58 |

## Recovered behaviour

The original unlocked-door rule at `0x0202DEC4` bypasses inspection for selected sides and map pairs. Room 215’s inside view flag is 1. The outside R213-to-R205 pair is explicit. `OriginalDoorTable.departsDirectly` now applies this rule before the session loads a close-up. It also corrects the extra handle action before Louie’s arrival.

Picture 22 uses the existing two-press touch-picture process. Page position `(96,225)` selects and confirms the notebook. Opcode 37 then records Melissa’s drawing at game offset `0x87B`, bit 0. The native notebook now displays this drawing on page 4. See [Original notebook](notebook.md).

After the picture and reminder, the original returns to hallway exploration. Talking again opens an empty question menu. Its inventory action remains available. The native menu now offers owned items through the same conversation boundary.

`OriginalShownItemSelector` follows `0x02028E4C`: scan the person’s blocks at the current time, match modes 16 or 27 and item byte 16, then evaluate conditions. Failed conditions continue the search. Unresolved conditions stop explicitly. Selection retains the current session block, as the original does.

`OriginalEventRunner.showItem` accepts an owned item only during a question menu. It clears the person’s item marker through the recovered `0x02098AAC` rule and starts the selected response. Event 50 removes item 3. Its mode-27 completion follows `0x0203D61C`, returning to the question menu even when no topics remain. Leaving then selects event 55 and removes Melissa’s map marker.

## Original evidence

Inputs remain in `tools/reference/notebook-*.txt` and `tools/reference/melissa-*.txt`. Captures remain local under `extracted/reference`.

These captures continue the modified delivery fixture described in [Louie’s delivery](louie-delivery.md). The Melissa sequence adds no memory writes. These are component comparisons. A complete unmodified ROM route from registration through delivery and Melissa remains outstanding.

| Checkpoint | Save-state SHA-256 |
| --- | --- |
| `melissa-father-answer/page28` | `e017d71f91fab9fab0e0eee5c9630f6f5ba08f8995858bb5c5f2d50ade352ac1` |
| `melissa-father-answer/page33` | `8246af95ed2257b16a7253a44f22b99ad5250074e349d7093b436395605e83b9` |
| `melissa-piece-show/page7` | `29a0cfb0ce0735331aa0976aaaf49ad2acd97a56ef863927849198a5560ef406` |
| `melissa-piece-departure/page11` | `efe74ad7f14a7bcdf12bc0c520fc23b5b65c5c7afc66ad3da49d00fa6a46bace` |

`OriginalMelissaRouteTests` compares all 32,088 game-state bytes at ten checkpoints. These include both choices, both question menus, picture entry, drawing acquisition, repeat conversation, piece return and departure. All ten match.

`OriginalTouchPictureTests` confirms the complete notebook mask occurs in the captured original process. It checks two presses and process completion. Selector checks cover person, item, time, condition failure, unresolved state and item-marker bounds. An unowned item leaves conversation state unchanged.

## Validation on 18 October 2026

The combined run passed 43 targeted Swift checks with no failures or skips. It covered both native input routes, doors, Louie, Melissa, shown-item selection, event execution, close-ups and touch pictures.

The README’s `swift test` command was used with filters for those suites. `SNAPSHOT_DIR` captured the native pages. Swift, GPU, audio and window-server access required sandbox escalation.

The notebook picture, empty question menu and returned hallway snapshots were inspected. The menu exposes **Items** and **Leave**. The hallway no longer shows Melissa’s marker. `git diff --check` passed.

## Remaining work

- Complete later grouped notes and the wider notebook menu. Melissa’s drawing and three writable pages are now connected. See [Original notebook](notebook.md).
- Mila and Rosa now pass the native route through the 5:20 time change. Continue with Jeff at Room 213. See [Mila and Rosa](mila-rosa.md).
- Recover shared System responses for unrelated shown items. These currently halt explicitly.
- Compare alternate answers, missed interrupts and other shown-item transitions.
- Connect original portraits, character backgrounds, item presentation, animation, fades and scene audio.
- Check iOS and physical Duo touch, hinge and lifecycle behaviour.

The notebook currently appears without Melissa’s portrait behind it. Conversation and inventory menus use native text controls. State comparisons do not establish complete audiovisual fidelity. The full game remains unfinished.
