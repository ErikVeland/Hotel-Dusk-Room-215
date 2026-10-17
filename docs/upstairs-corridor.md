# Upstairs corridor

Native play now enters R213, map 39, after the first jigsaw and dropped-piece pickup. Walking west starts Jeff's conversation. The normal session check completes it and walks to Room 215 with ordinary input.

## Original comparisons

| Checkpoint | Compared state |
| --- | --- |
| `dropped-piece-combined/upstairs` | Map 39 from map 17. Entry position `(16449,12288,6766)`, from model marker `out_r117`. |
| `r213-west/west` | After 21 westward movement updates, position `(8784,12288,6766)` enters region 2 and selects event 2. |

The reference input holds raw `(127,20)`. See [`upstairs-entry.txt`](../tools/reference/upstairs-entry.txt). The capture includes later frames while the event waits for dialogue. The position agrees with 21 native movement updates of 365 fixed units each.

The map controller is at `0x0227CFA0` in these captures. Its current position is at `+0x15514`. The talk controller at `0x02376FB0` holds event mode 3, ID 2. The westward checkpoint SHA-256 is `28894665974267b9b3e91ffab38153ebea8f8f8c97f5ed9dd670d2c7860c62e4`.

The original movement handler `0x0202CE5C` applies its extra factor of 1.35 to map 39, as it does to map 17. The native route now applies this factor in both supported corridors.

## Resources and floor plan

`tools/recover_lobby.py` bundles `R213.col` and records its source, payload and decoded hashes. Geometry, textures and the floor-plan payload already existed in their resource bundles.

The floor plan has 863 tiles and a 256×1280 source raster. The native decoder previously limited each dimension to 1024. Its limit is now 2048, with the existing section, tile and index checks retained.

The original origin table at `0x020E02AC`, record 39, contains `(525,132)`. The map conversion adds eight vertical pixels. The original map controller therefore records `(593,168)` for the entry position.

The tile update at `0x02037020` starts from pixel coordinates divided by eight, minus `(16,24)`. After screen rotation, the visible source crop starts at `(497,-24)`. The native view had used 128 instead of 192 for its vertical scroll offset. This displaced the floor plan by 64 pixels. Later Room 215 work recovered separate scale values for R103 and R117. Their current views use those original values.

The R213 check compares original five-bit colour samples across the viewport, excluding the original cursor overlay. Geometry and the floor plan still have separate rendering paths. This sample check does not establish complete DS rasterisation fidelity.

The combined run on 17 October 2026 passed 46 targeted Swift checks with no failures or skips. It included the normal arrival-to-Jeff session, original RAM positions, floor-plan samples and page captures.

## Remaining work

- Compare Jeff's other answer choices, the missed second and third interrupts, and later conversations.
- Continue from the connected Room 215 telephone to the suitcase and paperclip sequence.
- Connect other upstairs search areas and doors. Unsupported exits remain blocked.
- Recover character rendering, dialogue backgrounds, camera timing and visible transitions.
- Check physical Duo input and an iOS build.

The walkthrough anchors are `CHP106` for Jeff and `CHP107` for Room 215. The native route check completes Jeff's guide conversation and reaches Room 215's door position. The native door action, key use, opening event and room entry are now connected. See [Room 215](room215.md).

## Jeff conversation comparison

The guide route uses choices 24, 26 and 28, then questions 9 and 4 in that order. These choices require all three interrupts. The event indices are `2,3,4,5,9,10,11,13,14,15,16,21,18,23,24`.

The native runner returns to map 39. Its complete 32,088-byte game state matches `jeff-complete/complete-ram.bin`. The normal session check also reaches this outcome from arrival without injected process results. That session check verifies route progression rather than a complete rendering match.

Missing the first interrupt selects events `2,3,7`. Jeff returns to his room without setting game flag 35. This branch also matches all game-state bytes in `jeff-missed/missed-ram.bin`.

| Reference checkpoint | Save-state SHA-256 |
| --- | --- |
| `jeff-complete/complete` | `29d25609e9c66ada118324993f317b4ab43b221855de78dbfa902071dce06e51` |
| `jeff-missed/missed` | `98ec13071aa7540280be105ae2689670eebf1e5295930f1df23eb08c05c4807f` |

[`jeff-conversation.txt`](../tools/reference/jeff-conversation.txt) records checkpoint-based inputs for the conversation stages. [`jeff-missed-interrupt.txt`](../tools/reference/jeff-missed-interrupt.txt) records the missed first interrupt. These inputs depend on the local captures named in each file.

## Room 215 door recovery

The original internal destination is map 31 (`R205`). From the Jeff trigger position, 233 westward movement updates and nine southward updates reach `(-76261,12288,10051)`. The original map controller selects destination 31 at `+0x14610`.

`OriginalMapExploration.nearbyDoor` reads `in_` model markers in their original order. The original selector `0x0209D3FC` uses a distance limit of `0x3000` and a 60-degree facing cone. It checks the first eligible marker, then applies story and standing-person restrictions through `0x0202E938`. It does not choose the nearest door or fall through to another door after a restriction.

Collision nodes with vertices disable their matching door marker (`0x0209C370`). In R213, this excludes `in_r117`, which uses the separate stair transition. Native direction and cone calculations currently use floating-point maths. Exact fixed-point edge behaviour remains unverified.

`door_flg.bin` record 32 connects maps 39 and 31. The hallway-side view flag is zero. The room-side flag is one. Record order matters: the two connections between maps 39 and 45 resolve to the first record, ID 41, in either direction.

R213's search table maps door 32 to area 7, up-view 341 and model name `R213_L`. Its second table now has typed door records. Map state 10 starts process 93 (`0x02034888`), which starts process 98 (`0x020614B0`) for the close-up. The original first-entry narration appears on the other page before the door controls become available.

| Reference checkpoint | Save-state SHA-256 |
| --- | --- |
| `room215-near/door-near` | `fa2297266225a6ad485c172ae191da04dd0d4a030fb41338444279d4125d76c2` |
| `room215-door/door` | `7ff4f0478a9c402a81a610a8fc2b5faf340142372867ce1f2cb5c0d87b966905` |

The reference inputs are in [`room215-door.txt`](../tools/reference/room215-door.txt). The native close-up, key selection, knob hit test and room entry now have state comparisons. See [Room 215](room215.md) for the later checks.

The combined route and regression run passed 30 targeted Swift checks on 17 October 2026, with no failures or skips. `git diff --check` also passed. The page captures show the native hallway and door approach. Physical Duo input and iOS remain unchecked.
