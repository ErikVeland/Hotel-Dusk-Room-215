# Route tracing workbench

This document separates verified route progress from open route questions. Use it to plan focused trace work. Do not treat an inferred event or condition as verified gameplay.

## Trace record to add

The first tool change should add an opt-in route trace to the native runner. It must not change event selection or game state.

Record one JSON Lines entry for each selection, command, input and process return. Include:

- Run ID, input step and checkpoint name.
- Map, previous map, time, block, mode, scene, event, area, subarea and inventory.
- Each structurally matching event candidate, its source offset and condition key.
- Condition result, condition source offset and unresolved probe.
- Selected event or no-match result.
- Command source offset and operation name or raw opcode.
- State changes, process ID, process return value and resulting transition.
- Evidence status: verified, inferred or unknown.

Keep raw values beside decoded names. When the runner cannot explain a result, record the unresolved value and stop. Do not replace unknown state with false.

## Trace implementation progress

- Opt-in JSONL tracing is implemented for input boundaries, selector candidates and results, executed operations, and process returns. Trace records mark direct runtime observations as `observed`.
- Operation records include byte-level state changes. Input boundary records include a state hash and decoded summary; a concise event-level diff is still useful for comparing longer routes.
- An isolated Chapter 9 pantry probe seeds map R112 at time 4 with event 23:4 complete and the two Dunning desk items. A normal pan-zero hit on area 3 object `obj06` selects candidate event 2 with its condition passing, then returns to exploration. This confirms the trace path and one local selector result. It does not verify the secret-door quiz or the normal route into this state.

## Current route blockers

Priority means: P0 blocks the full story route; P1 blocks a chapter route or its branch; P2 is an interaction or fidelity gap outside the main route; P3 is a focused check for an earlier puzzle.

| Priority | Interaction and walkthrough notes for the player | Native status, difficulty and next trace |
| --- | --- | --- |
| P0 — Chapter 9 pantry gate and Chapter 10 cellar | After reading Dunning's birthday cards, return to the pantry and examine the locked door in its top-left corner. This starts Quiz 9. The walkthrough gives answers: Room 217, Jenny, nine years old, Robbins, birthday cards. In the cellar, inspect the back shelf for the missing whiskey, take the half-full bottle from shelf X, pour it into the bottle on shelf Y, then use the full bottle on the back-shelf case. Examine the whole shelf to reveal the passage. [Walkthrough CHP923 and CHP001](https://gamefaqs.gamespot.com/ds/933043-hotel-dusk-room-215/faqs/46777) | This is the main route gate into Chapter 10. The native route reads the birthday cards, but normal input has not yet verified the pantry door quiz or the cellar handoff. Trace the door tap, candidate events, quiz result, chapter transition and cellar arrival. Then trace both bottle searches, item use and shelf transition. |
| P0 — Chapter 10 timed escape | In the underpass, double-tap the barred door handle and enter. Read the guest register and Life Trivia book, then inspect the blue book twice after the trap closes. Check the machine and loose cord, take the hammer from the red toolbox, open the top drawer with the photo date code `518`, and take the letter. In the lower drawer, use the pencil on the file to make graphite, then apply it to the loose plug. Use the black light on the invisible-ink paper, set the machine dial to that number, and type the letter's two codes. The codes and dial number vary by game. Leave before the air runs out. [Walkthrough CHP002](https://gamefaqs.gamespot.com/ds/933043-hotel-dusk-room-215/faqs/46777) | The port has isolated handlers for several pieces, but the normal route through the time limit is not verified. It joins many object hits, inventory uses, generated values, process returns and a failure path. Build one ordered trace from the underpass entry through machine completion and exit. Record every time update and game-over boundary. |
| P0 — Chapter 10 wall and ending | After leaving the basement, hug the right wall to trigger the hammering scene. Examine the fallen bricks and gaps. Tap the wall until Kyle asks for a stronger tool, use the hammer, then remove bricks until the door appears. In the hidden room, tilt the camera right to find the palette knife, use it on the covered painting, and brush away the white covering. The final conversation has required answers. The walkthrough lists the sequence. [Walkthrough CHP003–CHP005](https://gamefaqs.gamespot.com/ds/933043-hotel-dusk-room-215/faqs/46777) | The native wall process remains a major technical blocker. Its 90 3D bricks use source transforms and hit-ray rules. A fixed ready-state is still needed for reliable comparisons. The normal route into the wall and through the final conversation is unverified. Trace the event trigger, hammer use, brick removals, door reveal and each final dialogue choice. |
| P1 — Chapter 8 bowling and rooftop | Talk to Louie in his room, then meet him in the Left Hallway. Hold the ball and move it slowly towards the pins for three rounds. The walkthrough expects about eight or nine pins per roll. Louie's third roll hits a plant and reveals the old key. Give Louie the key, go to the roof, tap Mila's shoulder, read her notebook messages, then escort her to Rosa's room. [Walkthrough CHP811–CHP821](https://gamefaqs.gamespot.com/ds/933043-hotel-dusk-room-215/faqs/46777) | The native model reaches a low-speed rooftop branch. A source capture scores 6, 6, 6, 5, 5, while the native model scores four each throw. Later notes also show the R118 arrival event blocked because flag 24:40 is clear. Capture one normal-route game, each throw result and the flag writer/trigger. Reconcile the conflicting claim that Chapter 8 reaches the Chapter 9 title. |
| P1 — Chapter 7 tree search and decoration | In the storage room, move the top-left box down and right, then the box below it. Move the top and lower boxes in the middle column right. Clear the two boxes in front of the tree box. Move the third front-row box up, stack the second on the fourth, and move the first right. Move the second box in row two right, then the first box in row three right. Tap the tree box. Next, match each decoration to a hook of the same colour and put the star on top. [Walkthrough CHP712–CHP713](https://gamefaqs.gamespot.com/ds/933043-hotel-dusk-room-215/faqs/46777) | Native route notes leave target placement inferred. Process 55's target fields are not set by recovered setup, and process 43's target-to-page fit lacks an original-run comparison. Capture the ready state, object target positions, drags and final return. Reconcile the route summary with later notes that leave some Chapter 7 scenes open. |
| P2 — Chapter 6 vending and wine label | Exchange cash with Dunning for four quarters in Chapter 4. In Chapter 6, use the coins on the vending machine, put one in the slot, and enter the total from the seven star numbers. For the wine label, spread adhesive remover over the red bottle's label, then drag the lifted corner down. Do not tear it. [Walkthrough CHP411, CHP603 and CHP622](https://gamefaqs.gamespot.com/ds/933043-hotel-dusk-room-215/faqs/46777) | The story route uses normal inputs, but process 46's original gesture and return are not checked. Vending and jukebox playback remain unverified. The total is per-save data, so use the seven recorded star values rather than a fixed code. Trace one clean run from coin exchange through prize, and one label peel through the story return. |
| P2 — Chapter 8 cassette | Find the tape and envelope in the utility-room rubbish. In Louie's room, get the ballpoint pen, place the tape in the deck, and try the pen to see that it is too round. Use the pencil from Room 215 to rewind the tape. Put the tape in the deck and select Side B. [Walkthrough CHP802](https://gamefaqs.gamespot.com/ds/933043-hotel-dusk-room-215/faqs/46777) | Native inputs repair the tape and operate the deck, but the route test mutes audio and process 52 does not play the cassette recording. Compare the Side B screen, sound and story return from the same checkpoint. |
| P3 — Chapter 3 four-pin lock | Return to Room 218 after restoring power. Use the thick wire to press all four pins down quickly. Earlier pins rise again if the player takes too long. [Walkthrough CHP324–CHP325](https://gamefaqs.gamespot.com/ds/933043-hotel-dusk-room-215/faqs/46777) | The native process has input and source-event checks, but no complete solve check for process 78. Check whether it requires an ordered sequence or the rapid multi-pin action described by the walkthrough. Record reset behaviour and event return. This is not a current chapter-route blocker. |

The walkthrough also says the final Chapter 10 conversation ends the game after a fixed sequence of presses and questions. It identifies these answer choices: “You talked to him here,” “It was Bradley,” “It was Nile,” “You lied,” and “He didn't say a thing.” The player then asks why Dunning kept Mila a secret. Trace these as story choices, not puzzle mechanics. [Walkthrough CHP005](https://gamefaqs.gamespot.com/ds/933043-hotel-dusk-room-215/faqs/46777)

The Chapter 9 apple route is already covered in normal-input notes. The player finds J under the one-apple painting, orders all five letters by apple count to spell JENNY, then closes and reopens the DS for the CPR action. Do not spend the next trace cycle on these steps unless a regression appears. [Walkthrough CHP913–CHP914](https://gamefaqs.gamespot.com/ds/933043-hotel-dusk-room-215/faqs/46777)

## Parallel analysis roles

Use agents for separate evidence tasks. Each agent should return source paths, offsets, observed state, confidence and the next unresolved question. Keep code edits with one integrator to avoid conflicting changes.

1. **Script graph analyst:** build candidate event and transition links from BLK and CHK data. Mark unknown conditions and command effects.
2. **Runtime trace analyst:** capture normal inputs and state changes from checkpoints. Find the first mismatch between the expected and actual selector result.
3. **ARM handler analyst:** resolve one unknown command, condition or process return from the recovered code. Return the handler address and a minimal source-backed rule.
4. **Route integrator:** join the evidence, update the route graph and select the next highest-value trace.

## Suggested implementation order

1. Compare the isolated pantry probe with a route trace from a genuine cards-read checkpoint.
2. Trace the Chapter 9 secret-door quiz and cellar transition. These still block normal Chapter 10 entry.
3. Add concise event-level state diffs if they make route comparisons easier to read.

The trace must preserve the current stop-on-unknown behaviour. It is an observation tool, not a permissive fallback interpreter.
