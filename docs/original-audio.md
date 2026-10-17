# Original audio recovery

The native audio adapter plays the original 36 music sequences with their source
instrument samples. It is not yet an exact replacement for the DS sound driver.
No game scene or chapter has been assigned an inferred track.

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
audio and puzzle effects. Their symbols and links are recovered. Native SSAR
playback and game cue call sites are not implemented.

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

The former synthesized effects are removed. `playSFX(name:)` reports an
unsupported cue and stays silent. It does not substitute a click, noise or
chime. Production game logic must use a recovered cue call site before playing
music or effects.

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
python3 tools/test_original_audio.py
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
