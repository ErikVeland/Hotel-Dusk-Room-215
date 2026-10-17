# Original ROM comparison runner

This is a local verification tool. It executes the supplied ROM to capture original screen pixels, audio, inputs and memory. It is not linked, bundled or called by the Swift game. Native game code must be reconstructed separately and compared with these captures.

The runner uses the GPL-3.0-or-later melonDS core at commit `906e9ebb27da8c6a715cd7abab4abfe8a8d29427`, with its software renderer, interpreter, generated firmware and FreeBIOS. This is a ROM execution reference, not a measurement from physical DS hardware. The upstream source and license are retained in `.tools/melonDS-reference`. The frontend in this directory uses the same license.

Build from the workspace root:

```sh
cmake -S tools/reference -B .build/rom-reference -DCMAKE_BUILD_TYPE=Release
cmake --build .build/rom-reference -j6
.build/rom-reference/hotel-reference 'Source/ROM/Hotel Dusk - Room 215.nds' extracted/reference/new-run < commands.txt
```

Use a fresh output directory for each trace. A run writes `inputs.txt`, signed 16-bit little-endian stereo PCM at 48,000 Hz, and `audio-cues.csv`. The CSV records changes in the original sound manager at `0x020FDC60`, including exact emitted audio-frame counts. Emulated frame duration follows the DS; it is not assumed to be 1/60 second. RTC starts at 2007-01-22 12:00:00; loading a state restores that state's clock.

Commands:

- `frames N`: execute N original video frames and drain audio.
- `keys MASK`: hexadecimal active-low DS key mask (`fff` releases all, `ffe` presses A).
- `touch X Y` and `release`: original 256×192 touch coordinates.
- `lid 1` and `lid 0`: close and reopen the original DS lid input.
- `capture NAME`: save both original 256×192 displays as PPM and all 4 MiB of ARM9 main RAM, based at `0x02000000`.
- `save NAME`: save an emulator checkpoint under this run directory.
- `load PATH`: restore an existing local checkpoint. Trace frame counters start at zero for the current run; they are relative to its input sequence.
- `until32 ADDRESS VALUE LIMIT`: advance at most LIMIT frames until a main-RAM word equals VALUE (hexadecimal address and value).
- `until-nonzero32 ADDRESS LIMIT`: advance until the word becomes nonzero.
- `write8 ADDRESS VALUE`, `write16 ADDRESS VALUE`, `write32 ADDRESS VALUE`: write an aligned main-RAM diagnostic fixture (hexadecimal address and value). Every write is recorded in `inputs.txt`. A modified run is an isolated component test, not evidence of a normal story path. Keep its output separate from unmodified playthrough captures.
- `trace-cinematic ADDRESS`: log the original queue's active object, handler and first state fields each frame in `cinematic-frames.csv`; hexadecimal ADDRESS is the controller base (opening: `022543f4`). Use `0` to stop tracing. This reads game memory without modifying it.
- `quit`: stop the run.

The microphone provides silence; network, DSi camera and accessory input are disabled. Captures cannot verify microphone puzzles until scripted microphone input is added. Cartridge save writes are confined to the trace directory. A checkpoint is specific to the pinned core build and supplied ROM.

The opening trace files record actual input sequences. Native comparisons must identify both the trace and checkpoint; a decoder hash alone does not establish story, puzzle or audio playback fidelity.
