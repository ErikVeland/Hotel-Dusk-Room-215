# Room 215, telephone and suitcase

Normal native play now reaches Room 215 after Jeff's conversation. The player can inspect its door, select the room key, unlock it and enter. Walking to the dresser enables inspection and Rachel's telephone call. The route now continues through the suitcase-key puzzle and broken-key dialogue. See [Suitcase key](suitcase-key.md). The complete game remains unfinished.

## Checked route

1. Inspect the Room 215 door in R213.
2. Advance the entry narration.
3. Select **Items**, then the Room 215 key.
4. Select the knob. Select it again, or press **Use**.
5. Advance the unlock narration.
6. Select the knob twice and advance the opening presentation.
7. Advance the room-entry dialogue.
8. Walk around the bed to the dresser and face it.
9. Select **Inspect**, then select the telephone twice.
10. Advance Rachel's call. Use **Back** to return to walking.

The original internal room name is `R205`, map 31. Door 32 connects it to map 39, `R213`.

The full native session check starts at Chapter 1 arrival. It reaches this checkpoint without a debug fixture or injected process result.

## Door mechanics

Once unlocked, later Room 215 entry and exit can bypass the close-up. The original `0x0202DEC4` rule uses side flags and explicit map pairs. Door 32 has inside view flag 1. The outside R213-to-R205 pair is explicit. Louie’s arrival also uses this direct departure path.

The R213 search table maps door 32 to area 7 and up-view 341. The close-up layers are `wall01`, `door01`, `nob01R` and `plate215`. Their component event IDs are 342, 343 and 344.

`OriginalUpViewTable` decodes the original table. `OriginalUpViewImage` composes the indexed images and packed hit map. The background is opaque. Overlay palette index zero is transparent. The original hit function `0x02059DEC` selects its packed nibble using page-X parity. The native implementation preserves this behaviour.

Both the full 24,576-byte hit map and the full 98,304-byte colour buffer match the original RAM capture. Screen rendering still has DS filtering differences.

| Action | Original event |
| --- | --- |
| First door inspection | R213 event 25, mode 13 |
| Room key on knob | Event 26, mode 16, item 1, target 343 |
| Open unlocked door | Event 27, mode 14, target 343 |

Event 26 sets door state zero. The key remains in inventory. The existing `.doorOpen` condition name returns the stored nonzero state, so it is false after unlocking. Event 27 must run before map departure even though its dialogue packets contain presentation controls without visible text.

The session applies the original departure selector before changing maps. This preserves the room's telephone reminder gate. Door inspection and component selection now use the original System fallback when the room has no matching event. This follows modes 13 and 14 in `0x0203A444`. Door item use also uses the existing mode-16 fallback. An unrecovered response still stops explicitly.

## Room placement and map

The entry marker `out_r213` places Kyle at `(9994,12288,-15811)`. Room-entry request 9 then selects `hyde_point00`, placing him at `(7291,12288,16630)`. His facing is approximately `0.39410695` radians. Position and facing match the original saved bytes.

The map consumer `0x0202C264` handles this request through `0x0209D794` and writes persistent placement through `0x02097198`. Requests use stack order. Map construction marks the visited byte through `0x020982C8`.

The original map scale table at `0x020DFF60` supplies 12.7 pixels per world unit for R205. R103 uses 14.7, R117 uses 14.2, and R102/R213 use 17. The 256×256 room map omits the large-map tile offsets and clamps scrolling. The native room floor plan matches sampled original colours outside the cursor and suitcase overlays.

The recovery tool now bundles R205 collision, 40 original up-view tables and the original inventory labels. It also refreshes the `telephoe.dtx` manifest entry. The existing partial-height compressed-texture decoder handles this 32×36 texture. This does not establish a complete texture or rasterisation match.

## Telephone and branch conditions

From the scripted room position, the compared route walks west to the bed, north around it, then west to the dresser. The final position is `(-16687,12288,7450)`. Search area 1 uses the original `R205_s01` geometry, cameras and hit meshes. Page point `(86,165)` selects telephone node `obj01`.

The phone starts event 9, passes through empty event 11, then runs Rachel's event 12. Request 5 returns the original search presentation to the dresser. Native play retains that inspection view after the call. Its complete 32,088-byte game state matches the original call checkpoint.

The guide's second call is conditional. This checked route already has game flag 9 from the earlier Dunning conversation. Event 14 therefore does not start the payment reminder. The extended native route now follows events 14 and 15 and reaches the parcel announcement after breaking the suitcase key. A matching original run for this branch remains open. See [Dunning and delivery](dunning-delivery-route.md).

## Reference checkpoints

These captures use the supplied ROM and the reference runner described in [its README](../tools/reference/README.md).

| Checkpoint | Save-state SHA-256 |
| --- | --- |
| `room215-ready/ready` | `5f1125b15b2886a458e7c945e2ed4dbaa3edae29860190af677ea8c21b96daca` |
| `room215-open/ready` | `1dca87ca1a2f2794e149743e47654eb213fe77d33d6e3a5c682ee87a747fd296` |
| `room215-enter/entered` | `d05f9fc7839b680ec1e0c3375b07afb44556bcf9d035734cd5e9574a43f2633f` |
| `room215-room/room` | `e7e75070f9d898ce70d96c537a9643326e738fdd9b0e47acb78108845341b187` |
| `room215-phone-dialogue/call20` | `21d64f0c7859847c6c910af72643194e9d4c6c4cc162afbc066e891a0ac4e750` |

The `tools/reference/room215-*.txt` files record the inputs and expected output directories. They load the named local checkpoints. Telephone dialogue needs both touchscreen and A-button input because the active dialogue moves between screens.

## Validation and remaining work

On 17 October 2026, the initial 20 targeted Swift checks passed with no failures or skips. These include the normal route, state comparisons, floor-plan samples, door buffers and page captures. The expanded 42-check regression found stale texture-count expectations. After updating those counts, the four texture checks passed again, including all 2,921 decoded texture hashes. All 42 distinct checks now pass across these runs. Seven Python recovery checks and `git diff --check` also passed.

The later suitcase increment passed 48 targeted Swift checks in one run on 17 October 2026. This includes the normal route from arrival, puzzle outcomes, full-state comparisons, textures and rendering.

Remaining work includes:

- Mila and Rosa. The notebook now displays Melissa’s drawing and supports three writable pages. See [Original notebook](notebook.md). Melissa’s notebook conversation and puzzle-piece return now have native route and original component checks. See [Melissa’s notebook and piece return](melissa-notebook.md). Wrong-parcel inspection and notebook acquisition now have native route and original component checks. See [Wrong parcel and notebook](wrong-parcel.md). Native input now completes Louie's first conversation. See [Louie's delivery](louie-delivery.md). The ordinary delivery clock transition returns to Room 215. Paperclip straightening and the thin-wire lock attempt now have native route and original-state checks. See [Thin-wire lock attempt](thin-wire-lock.md).
- Original comparison for the alternate Dunning call, plus other optional inspection responses.
- Original inventory presentation, selection highlights, portraits, camera transitions and sound cues.
- Dynamic floor-plan objects, including the suitcase. Original flags now control room and search model visibility.
- Device input, iOS and physical Duo checks.

The inventory uses native text buttons and selects an item immediately. Door and search presentation still use native controls. These differences remain separate from the checked story state.
