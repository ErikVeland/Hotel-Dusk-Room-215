# Wrong parcel and notebook

Normal native input now continues from Louie's first conversation to the parcel on the bed and collects the brown notebook. Both supplied walkthroughs place this before the next Melissa conversation. The detailed guide uses anchor `CHP112`.

## Original behaviour

- Room 215 is map 31 (`R205`). Bed area 2, subarea 2 opens view 251.
- Mode 10 selects event 69 on the checked route. Close-up entry then selects mode 11 and event 71 automatically.
- View 251 combines background `205sudan` with notebook layer `205note`.
- Two presses on the notebook confirm layer event 252. The checked branch selects script event 74.
- The script enables keyword 14 and awards inventory item 5 through the original item notice.
- The notebook's acquisition state removes its image and touch mask. The empty box remains available.

Process 98 starts the background response in `0x02062F08`, case 4. Its initial state reaches this branch through `0x02061E08`. The A-only `wrong-parcel-entry` capture confirms that no background touch is required.

## Object visibility

`OriginalObjectVisibility` decodes the 84 records in `onoffobjs.dat`. `OriginalGameState.objectVisible` reads the original flag bank at offset `0x852`.

The room renderer uses each record's room node name. Search rendering and picking use its `objNN` subarea name. Both respect the same visibility flag. The checked delivery enables flag 1 for the wrong parcel. Flag 2 keeps the later parcel hidden.

Source addresses are `0x0202C624` for room visibility, `0x02033938` for search visibility and `0x02097E28` for flag lookup. Setter `0x0208C5A4` changes the first node whose name has the supplied prefix.

The table also contains floor-plan sprite names and positions. Dynamic floor-plan objects remain unimplemented.

## Reference evidence

The `tools/reference/wrong-parcel-*.txt` files retain the inputs. Captures remain in the ignored `extracted/reference` tree.

These captures continue the modified delivery fixture described in [Louie's delivery](louie-delivery.md). No further memory writes occur in this sequence. They establish component behaviour. A complete unmodified original route from registration through delivery remains outstanding.

| Checkpoint | Save-state SHA-256 |
| --- | --- |
| `wrong-parcel-bed4/inspect` | `3720f84580788646e836c5937ac0a113b626bf4e437b5d81bae7a5ca8976e20c` |
| `wrong-parcel-entry/page4` | `4a8bbdf38c82778dbbaf082e1207b9fb77c9de7d6b93a70166b7e7c556a5e78a` |
| `wrong-parcel-open/page3` | `559c89452d85ffb83813142f637fa1dddd04be2aefb4163eeb4a7c832d525b6d` |
| `wrong-parcel-notebook/page12` | `d4717d5d21c81fa88758e33e39cdb061f7395c601466d6e6a762bdca4199d6bd` |

All 32,088 game-state bytes match after the entry responses and after notebook acquisition. The composed RGB555 images and complete packed hit masks match original RAM before and after pickup.

## Native checks

On 18 October 2026, all 38 targeted Swift checks passed together with no failures or skips. They cover close-ups, visibility, lobby picking and rendering, doors, Louie, the upstairs route and two normal-input session routes. One reaches the paperclip and thin-wire attempt. The other reaches notebook acquisition after Louie's delivery.

The extended route starts at Chapter 1 arrival. It uses session input without injecting inventory or process results. Bed, notebook and empty-box snapshots were inspected.

## Next route and limits

- Melissa’s notebook picture, puzzle-piece return and departure now have native route and original state checks. The notebook now displays Melissa’s drawing. Continue with Mila and Rosa. See [Original notebook](notebook.md). See [Melissa’s notebook and piece return](melissa-notebook.md).
- Compare alternate parcel descriptions and notebook acquisition branches with original execution.
- Connect dynamic floor-plan objects, original selection graphics, portraits, transitions and audio cues.
- Verify iOS and physical Duo input separately.

The complete game remains unfinished. Guide instructions select the route. Original scripts and matching captures determine its implementation.
