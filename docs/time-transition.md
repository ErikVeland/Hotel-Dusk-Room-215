# Time-change command and clock process

Opcode 16 now decodes its request and label, queues the request, clears the previous map, and enters clock process 126. The ordinary clock process now runs its hand updates and label animation, then returns to Room 215. The special `08:00AM` transition remains unsupported.

## Recovered sequence

| Step | Original code | Native behaviour |
| --- | --- | --- |
| Queue the request | `0x0203C4AC`, `0x020971D0` | Retain signed byte 2 and signed short 4 in the request stack. |
| Select the clock | `0x0203C4AC` | Read the terminated label from byte 6. The exact sentinel `NONE` suppresses the child. An empty label still starts it. |
| Clear the previous map | `0x0209714C` | Preserve the current map and set the previous map to zero. |
| Initialise the child | `0x0205D8FC`, `0x02098868` | Substitute `05:00PM` for an empty label. Copy the label and terminator to game-state offset `0x1346`; preserve the remaining bytes. |
| Run the clock | `0x0205DA48` and its helpers | Run the ordinary clock and label states after loading the original bitmaps. Return value 2 resumes the parent event. |
| Consume map request 3 | `0x0202C264`, `0x02097E5C`, `0x02029704`, `0x02097BEC` | Set the numeric time slot and clear all 47 × 18 saved conversation blocks. |

The label and numeric time change at different points. The numeric time remains zero while the Room 215 clock is running. It becomes one after the clock and parent talk return. Clearing conversation blocks is required even when the map does not change.

`OriginalTimeTransition` owns command decoding. `OriginalEventRunner` owns the child handoff and script continuation. `OriginalPlaySession` consumes map requests in reverse order when exploration resumes. The host does not fabricate a clock result.

## Original component comparison

`tools/reference/time-transition-fixture.txt` loads the earlier Room 215 checkpoint and sets three completed-question bytes to start the delivery event. This is an isolated component fixture, not evidence of a normal story route. Its input log records every RAM write.

`OriginalTimeTransitionTests` starts from the captured knock dialogue with the observed event-30 selection context. It compares all 32,088 state bytes at:

- `time-transition-fixture/page3`: clock active, label `05:10PM`, numeric time zero, previous map zero.
- `time-transition-fixture/page4`: return to Room 215, numeric time one and cleared conversation blocks.

The second comparison now drives the native clock to completion before returning its result. It checks script completion and map effects. The separate counter trace checks the active clock timing. The first comparison exposed the missing conversation reset; the corrected implementation matches both captures.

Fourteen targeted logic tests passed on 17 October 2026 with no failures or skips: time-command comparisons, Dunning and hallway comparisons, and event-runner checks. Both rendered native routes also passed. The delivery route now checks entry to the clock command after its parcel snapshot. The rendered checks needed CoreAudio and window-server access; their first sandboxed attempt failed during audio setup. `git diff --check` passed.

## Clock process and presentation

The original clock uses these existing bundled resources:

- `OriginalBitmaps/trick/clock/{clock,hour,min,sec}.bin`
- `OriginalBitmaps/talktest/TalkTime/0510pm.bin` and the AM/PM transition layers.

Relevant original functions are `0x0205E6D4` for loading and initial clock state, `0x0205E57C` for queued image completion, `0x0205ECE0` for clock-image setup, `0x0205EE60` for timer and hand updates, and `0x0205E1A8` for label animation. `08:00AM` has a separate branch and must not inherit the ordinary transition's timing.

`OriginalClockProcessTests` compares all counters, hand times, alpha and label stages across 245 consecutive original frames. The test supplies the captured second counter as the clock input. It also checks minute rollover, completion and unsupported labels. The model keeps clock updates separate from the alternating display frames.

`OriginalClockRenderer` uses the original clock face, three hand images and seven label images. Palette zero is opaque white in the clock face. Hand projection uses the captured orthographic scale `3068/4096`, translation `-1707/4096` and pivot `164/4096`. CoreGraphics rasterisation is not a pixel-exact DS comparison.

`OriginalPlaySession` loads bitmaps synchronously before starting the active clock. Its retained frame counter supplies seconds at the session's 59.8261 updates per second. Pausing freezes that counter and all animation state. The session plays the original tick cue at archive 0, entry `0x43`. The clock completes without user acknowledgement.

The final logic run passed 18 tests with no failures or skips. Both native routes passed, including clock pause/resume and return to Room 215. The extended route then passed through Door, handle selection and event 31 to Louie's event 32. One attempt crashed in a CoreAudio render callback. The unchanged retry passed. The corrected standalone clock image was inspected. `git diff --check` passed.

Remaining fidelity work includes original resource-upload latency, the phase of the hardware second counter, surrounding fades, exact rasterisation, audio comparison and the `08:00AM` branch. A complete unmodified original route from the required Dunning questions through delivery is still being recorded. The native route now completes Louie's first conversation. The wrong parcel and notebook remain next. See [Louie's delivery](louie-delivery.md).

## Door handoff

The native route currently opens a door close-up before the player selects its handle. The original component capture starts event 32 directly from the Door action. This extra native interaction remains a fidelity gap. `delivery-door-fixture` and `louie-arrival-pages` continue from the explicitly modified time fixture. They do not establish a complete unmodified story route.
