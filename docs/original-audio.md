# Original audio recovery

The native audio adapter plays the original 36 music sequences with their source
instrument samples. It is not yet an exact replacement for the DS sound driver.
No game scene or chapter has been assigned an inferred track. Dialogue and
walking use recovered source controls and tables.

## Switchable music sources

**Book options → Music source** and the pause menu offer **Native music** and
**Recorded soundtrack**. Native music remains the initial default. The app stores
the selected source in user preferences, separately from game saves.

`Source/hoteldusk-soundtrack` supplies all 36 MP3 recordings at 44.1 kHz stereo,
320 kbps. `tools/prepare_recorded_music.py` copies their bytes into the bundle
without re-encoding. Its manifest records source hashes, sequence IDs, native
timing, recording offsets and measured repeat boundaries. These are supplied
recordings, not a verified release of higher-resolution masters.

The 33 looping tracks use repeat regions before their album fades. The tool
compares 12-second energy envelopes across repeats and rejects correlations below
0.94 or timing errors above 10 ms. Source sequences 02, 05 and 27 play once.
The native/recording time conversion preserves introductions and tempo changes.

`RecordedMusicPlayback` streams the introduction and queues a decoded PCM loop
ahead of playback. A 128-frame blend at the join removes sample-phase clicks
without shortening the repeat. This also avoids decoder padding at each loop.
Only the active recording's loop is retained in memory.

Switching sources prepares the replacement before stopping the old source. It
transfers the current musical position and crossfades over 150 ms during play.
Switching while paused retains the paused position. Music fades, mute, volume
and sound effects remain under the same controller. A preparation failure keeps
the existing source playing and reports the error. Both sources use per-cue level calibration from complete introductions and loops.
The native sampler was 10.76–22.62 dB louder by RMS before correction. Native
output is attenuated to match the recordings, and both sources retain 3 dB of
shared headroom. This changes gain, not musical dynamics or file contents.
Listening on the target device is still needed to assess perceived loudness and
timbral changes. `docs/audio-source-profile.json` retains the baseline measurements;
`tools/calibrate_music_levels.py` reproduces the bundled calibration and binds it
to both exact resource manifests.

The controller retains at most one alternate backend for the current cue, with
its transport paused and muted and its engine graph ready. Switching back reuses it. Changing the cue or stopping the
session releases it. The largest decoded recording loop is 42.91 MiB, excluding
engine, sampler and decoder allocations. A first switch still prepares its backend
synchronously; current host measurements are recorded by the audio verification
profile. The final host profile is retained in `docs/audio-source-runtime-profile.json`.
Timings exclude the 150 ms crossfade and are not target-device results. Physical
footprint values describe the test process, including frameworks and retained
allocations; they are not an isolated app or target-device memory budget.

## Source and coverage

`extracted/root/data/sound_data.sdat` is 6,297,024 bytes. Its SHA-256 is
`e409838b723198acf3e3b292ce17501ce711ea4c632effbd5547ddf355812891`.

The archive contains 340 byte-exact constituent files:

| Original data | Count |
| --- | ---: |
| Music sequences (SSEQ) | 36 |
| Sequence archives (SSAR) | 89 |
| Entries in those archives | 186 |
| Instrument banks (SBNK) | 125 |
| Wave archives (SWAR) | 90 |
| ADPCM sample entries | 291 |
| Sequence players | 17 |
| Preload groups | 123 |
| Streamed audio | 0 |

`tools/extract_sdat.py` preserves all constituent bytes. Its inventory records
original symbols, file IDs, sequence entry points, bank links, wave links,
volumes, priorities and hashes. `extracted/audio/inventory.json` is the full
record. Copies of all raw files are also bundled under `Audio/Nitro`.

The 186 archive entries include stingers, system sounds, footsteps, environmental
audio and puzzle effects. Native SSAR sequencing and sample rendering are
implemented. Recovered menu, dialogue and puzzle call sites select the cues.
Walking footsteps now use the map-specific pair of original cues, the original
6/8-tick cadence increments, and actual movement after collision handling. Idle
frames reset the counter to 200 after walking has started; untouched initial idle
does not advance the cadence (0x0202B100). Footsteps alternate on reaching 300. The room
ambience condition recovered from 0x0202DC70 starts archive 12 entry 0 in map 6
only while person slot 3 is there. Map cleanup stops that ambience over five
updates (0x0202CB58). Other room table entries are retained without assigning
unrecovered triggers. Door-transition and other remaining call sites still need
separate recovery. The independent Chapter 5 check also corrected the doll
stitch and completion cue archive/entry order.

## Music timing and samples

`tools/audit_sseq.py` traces the original sequence instructions, including track
creation, waits, notes, calls, returns and backward jumps. Unsupported commands
fail. It records source offsets and ticks instead of guessing loop duration.

All 48,315 supplied MIDI note events match the original sequences for onset,
pitch, velocity and duration. The audit compares simultaneous events as
multisets. Sequences 02, 05 and 27 terminate. The other 33 repeat. Their loop
ranges preserve introductions, including the 408-tick introduction in sequence
06 and the 3,072-tick introduction in sequence 16. The source has 48 ticks per
quarter note.

The supplied `Source/Music` DLS exports had defects. Several sample tails
contained inconsistent data. Wave 98 was truncated from 142,864 samples to
11,792. Their negative saturation also differed from DS ADPCM, and their sample
loop starts were offset from the original SWAR metadata.

`tools/prepare_original_audio.py` regenerates every music sample from the
original ADPCM and repairs RIFF sizes, sample-pool offsets and sample loops.
It retains the supplied conversion's instrument parameters. A single 5.57 MB
wave pool serves all 36 banks. The app assembles the selected bank in its cache
and checks its SHA-256. The bundled audio resources total about 13.1 MB,
including the original raw Nitro files.

## Native integration

`AudioController.playOriginalSequence(id:)` accepts the zero-based SDAT sequence
ID. `playBGM(title:)` accepts only exact original `SEQ_BGM_nn` symbols.
`pause`, `resume`, `stop`, `volume` and `isMuted` control native playback.
`AVAudioSequencer` and `AVAudioUnitSampler` use the repaired banks and recovered
per-track loop ranges. The audio engine starts only when playback is requested.

`OriginalDialogueAudio.json` preserves all 36 music lookups and 197 sound-code
lookups from ARM9. The sound table has duplicate names. Lookup retains source
order and uses the first match, as 0x0200AD94 does.

The text handler at 0x0204370C starts music for `%m0NN`, stops it over 20 updates
for `%m1NN`, and ignores other music modes. `%sCCCCCC0` starts the mapped effect;
other sound modes stop its player over one update. The native host applies these
controls once when it presents a dialogue packet. Exact control timing within
the book's rewritten text presentation is not yet matched to the DS renderer.

Walking music uses `mapsound.bin` and 0x0202DC70, including default sequence 17,
the Room 108 flag override and the bar's stored jukebox selection. Returning to
walking restores that music. Save reload stops the old session before starting
the new session, so it cannot stop the restored music afterward.

Audio ramps continue during dialogue, choices, inventory and chapter titles.
The book's pause state suspends them. Ending a session also stops effect players,
including looping cues. Playback and render errors appear beside mute and volume
controls in the pause menu. Unknown cues stay silent and report an error.

This adapter still needs comparison with DS recordings for envelopes, resampling,
modulation, mixing and sequence-volume response. MIDI controller conversion and
the supplied DLS instrument conversion are not fully verified. Pause/resume
retains sequence position but does not serialize active sampler voice state.
No end-to-end audio-fidelity claim follows from the resource checks.

## Reproduce

Run from the project directory:

```sh
python3 tools/extract_sdat.py
python3 tools/audit_sseq.py
python3 tools/prepare_original_audio.py
python3 tools/bundle_dialogue_audio.py
python3 tools/prepare_recorded_music.py
python3 tools/test_original_audio.py
python3 tools/verify.py --profile audio --strict
python3 tools/calibrate_music_levels.py docs/audio-source-profile.json
```

The Swift `OriginalAudioTests` verify source loops, bank reconstruction, cache
repair, rejection of invented cues and native instrument loading. Core Audio
must be available for the native sampler test.

## Format references

- [NitroStudio2 SDAT format](https://gota7.github.io/NitroStudio2/specs/soundData.html)
- [NitroStudio2 sequence commands](https://gota7.github.io/NitroStudio2/specs/sequence.html)
- [ndspy archive and sequence implementation](https://github.com/RoadrunnerWMC/ndspy)
- [melonDS sound implementation, used to check DS ADPCM saturation](https://github.com/melonDS-emu/melonDS/blob/master/src/SPU.cpp)
- [Apple AVMusicTrack loop ranges](https://developer.apple.com/documentation/avfaudio/avmusictrack/looprange)

These references informed format interpretation. The extraction and adapter
code in this project was written for this port. No emulator is linked at runtime.
