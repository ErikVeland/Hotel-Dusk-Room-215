# Mila, Rosa and the 5:20 time change

The checked native route now returns from Melissa to the lobby, gets Mila’s attention and completes Rosa’s first conversation. It reaches the ordinary 5:20 time change and returns to lobby exploration.

The detailed guide identifies this sequence as `CHP114`. The original scripts and captures determine its events and state changes. Existing script and picture handlers execute this route. Comparing the final state also exposed missing character collision and approximate facing calculations.

## Connected route

1. Return through the upstairs stairway to R117.
2. Use the side passage to R103, then return to R102.
3. Walk around the counter to trigger Mila’s entrance.
4. Approach Mila near the front door and select **Talk**.
5. Select and confirm her shoulder picture.
6. After Rosa’s introduction, face Rosa and select **Talk**.
7. Use the salesman interrupt, then ask about Mila, her room, Jeff and the wrong parcel.
8. Continue the telephone exchange and the 5:20 time change.

| Checkpoint | Original identifier |
| --- | --- |
| Lobby entrance | R102 region 3, event 66 |
| Mila’s standing marker | Person 5, marker 204 |
| Mila conversation | Event 67 |
| Shoulder interaction | Picture 24 |
| Rosa’s introduction | Event 69 |
| Rosa’s standing marker | Person 3, marker 203 |
| Salesman interrupt | Event 71, choice 10 |
| Initial question menu | Event 74, keywords 14 and 21 |
| Mila’s identity and bracelet | Keyword 21, event 75 |
| Rosa’s room | Keyword 22, event 76 |
| The driver | Keyword 23, event 77, choice 13 |
| Wrong parcel | Keyword 14, event 80 |
| Telephone exchange | Event 86 |
| Departure and clock | Event 89, process 126, time ID 2 |

The first question menu lists the parcel before Mila’s name. The checked route follows the guide’s topic order: 21, 22, 23, then 14. The original menu retains the unanswered parcel question while new topics appear.

## Behaviour and evidence

Mila’s shoulder uses the existing mode-0 touch-picture process. Page position `(96,225)` selects and confirms it. The full packed mask matches the original RAM capture.

The entrance and introduction use original map request 9. They move Kyle to `hyde_point00` and then `hyde_point02`. Rosa’s conversation becomes available after the player turns towards her.

Map movement now applies each character’s 8192-unit floor radius before wall collision, as recovered from `0x0202DA54`. Integer normalisation follows `0x020BD074`. Facing uses the original angle conversion table, fixed-point dot/cross products and cardinal easing from `0x0202CE5C`. All 4096 generated sine/cosine pairs match the source table at `0x020E272C`.

The reference’s final dialogue tap moves Kyle south for three updates. Its next held touch starts one frame after the command. After 29 northward updates, native and original positions both equal `(16226,12288,12029)`. Both facing values equal `2.9292964935302734`.

The room and driver questions become available through the original keyword commands. Event 86 requires the parcel question and completed event 77. Event 89 removes both characters and requests the next clock transition. The ordinary clock process returns to the lobby with time ID 2.

Reference inputs remain in `tools/reference/mila-*.txt`, `tools/reference/rosa-*.txt` and the `melissa-*-return` files. Captures remain local under `extracted/reference`.

These captures continue the modified delivery fixture described in [Louie’s delivery](louie-delivery.md). The route adds no memory writes. A complete unmodified ROM playthrough from registration through this scene remains outstanding.

The native session check starts at Chapter 1 arrival. It uses ordinary movement, dialogue, picture, choice and question inputs. It does not inject inventory, puzzle results or event flags.

`OriginalRosaRouteTests` compares all 32,088 game-state bytes at the shoulder picture, Rosa’s introduction, both choices and each question-menu checkpoint. It also compares the state before and after the clock, including the saved pose and retry checkpoint. A separate comparison covers the missed salesman interrupt.

On 18 October 2026, 49 targeted checks passed across movement, doors, conversations, touch pictures, upstairs events and both normal-input Chapter 1 routes. This includes the extended arrival-to-5:20 route. Native page captures are in `/tmp/hotel-rosa-collision`. Mila’s shoulder picture and the lobby after departure were visually checked. These results cover the macOS host. Physical Duo behaviour remains unverified.

```sh
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
SNAPSHOT_DIR=/tmp/hotel-rosa-collision \
swift test --filter 'OriginalLobbyExplorationTests|OriginalRosaRouteTests|OriginalTouchPictureTests|OriginalMapConversationTests|OriginalDoorTests|OriginalUpstairsTests|LayoutSnapshotTests.testRenderPlayableLobbyAndRingBellThroughSession|LayoutSnapshotTests.testRenderRequiredDunningQuestionsAndDeliveryKnock'
```

| Local save checkpoint | SHA-256 |
| --- | --- |
| `mila-talk-correct/page3.mln` | `cfc14af0717ea8cbc88a8df2b592a8a4d8cfe8bd9b29d47a263ff1068c4711d3` |
| `rosa-introduction/page21.mln` | `bc3e8f24531d58376b6d452e9b032fd1b68115112184b9d0edc2589233848435` |
| `rosa-salesman-answer/page20.mln` | `636cab452c34ecd053dc2459c34477e19479cd4a4c3cb3d11d0381aaf8da84e6` |
| `rosa-jeff-question/page14.mln` | `e1afeec76ae580b5ec48bff1093ca950a66c717d5d7baf62a6d7f45a5f588a1e` |
| `rosa-parcel-departure/page36.mln` | `3c77d2df491550063d849eea561a403307ba5e35ee0f09f1012fa86a2561198d` |

The next reference input file, `tools/reference/rosa-return-r103.txt`, returns from this checkpoint to R103 with ordinary movement. Its `returned` save is ready for the upstairs continuation.

## Remaining work

- Jeff’s Room 213 conversation is now connected. See [Jeff at Room 213](jeff-room213.md). Continue with Iris, Summer, the order documents and the Chapter 1 review.
- Compare alternate answers and other question orders.
- Connect original character portraits, animation, bracelet presentation, fades and scene audio.
- Complete the notebook’s conversation responses, wider menu and persistent saves.
- Verify physical Duo and iOS behaviour.

The full game remains unfinished. Passing route and state checks do not establish complete audiovisual fidelity.
