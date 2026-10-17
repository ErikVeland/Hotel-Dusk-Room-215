# Original logic recovery

This project is recovering the supplied game's data and logic for a Swift and SwiftUI rewrite. It does not ship an emulator. The extracted ROM is the reference for comparisons. Structural recovery is underway; the original game is not yet fully decompiled or playable through this native runtime.

## Reproduce the recovery

```sh
python3 tools/recover_original_logic.py
python3 -m unittest discover -s tools/tests -v
```

The first command creates `extracted/recovered_logic/index.json`, exact decoded script members, JSON structure records, decompressed code images, ARM ELF wrappers, and `dispatch.json`. Every member has a source hash and decoded hash. The index includes the ROM hash and original overlay load addresses. Raw extracted files remain unchanged.

The recovery passes bounds checks for all 610 members of `local/us/textdata_usa`. This includes 115 matched BLK/CHK/KIF groups, 107 debug maps, 115 indexed text tables with 63,662 entries, nine plain chapter summaries, and 34 other preserved members. The 115 BLK files contain 25,110 operations. Empty strings and original inline control codes remain intact.

## Container correction

Each unpacked WPF member retains a 32-byte archive directory record. Its payload begins with a 16-byte Cing envelope:

| Offset | Type | Meaning |
| --- | --- | --- |
| 0 | 4 bytes | `12 3D DA 00` for raw data; `12 3D DA 01` for compressed data |
| 4 | u32 little endian | Decoded byte count |
| 8 | u32 little endian | Compressed byte count, or `FFFFFFFF` for raw data |
| 12 | u32 little endian | Reserved, zero in these members |

Compressed flags are read low bit first. A set bit is a literal. A clear bit is a three-byte dictionary token: u16 read index and u8 length minus four. The dictionary is 65,536 zero-filled bytes. Its initial write index is 65,536 minus 259. Each copied byte updates the dictionary immediately, so overlapping references and wraparound are preserved.

The former `decode_jigsaw.py` approximation read from a preallocated output array. That can read bytes which do not yet exist in the dictionary. It corrupted two bytes in `EP1_R102.blk`, including the third table's offset: 512 instead of 544. `tools/cing_container.py` now models the dictionary directly. The jigsaw decoder uses it, and its images have been regenerated. SystemIcon's raw tiled members remain explicitly handled as raw data.

The container format was first documented by its researcher, [Jason Harley](https://jasonharley2o.com/reverse/hoteldusk/). The exact ring implementation here was independently checked against structural invariants across this ROM's chapter archive.

## Code recovery correction

The extracted ARM9 image is still compressed. Its stored size is 603,240 bytes; decoding the backwards-LZ section produces 1,031,352 bytes. The earlier `extracted/binaries/arm9_disassembly.asm` was made from compressed bytes and must not be used as a complete code listing.

The ARM9 load base is `0x02004000` and entry is `0x02004800`. The first `0x4004` bytes pass through the decoder unchanged. ARM7 is stored uncompressed. All 45 overlays are recovered using the ROM overlay table's flags, filesystem file IDs, load addresses, decoded sizes and initializer ranges. Static code is available for analysis; no C++ source or original symbol table has been recovered.

The backwards-LZ format is documented in the primary [ndspy implementation](https://github.com/RoadrunnerWMC/ndspy/blob/master/ndspy/codeCompression.py). Our decoder checks exact boundaries and rejects invalid references instead of repairing them.

To inspect ARM9 with the existing local tool:

```sh
python3 tools/disassemble_arm.py extracted/recovered_logic/binaries/arm9.elf extracted/recovered_logic/binaries/arm9.asm
```

A flat disassembly still includes data, literal pools and embedded code regions. Function boundaries and ARM/Thumb modes require separate analysis. An ELF wrapper is not decompilation.

## Verified script structures

All offsets below refer to decoded payloads, after the WPF record and Cing envelope.

| Member | Recovered structure |
| --- | --- |
| `.txt` | u32 count, then count u32 offsets. Offsets are relative to the bytes immediately after that table. Each referenced string ends with NUL. |
| `EP*_BOOK.txt` | Plain chapter-summary text, not an indexed table or a script. |
| `.dbg` | 32-byte records: u16 key, then a 30-byte NUL-padded original event label. |
| `.kif` | 64-byte records: 48-byte NUL-padded choice text and four raw u32 fields. |
| `.blk` | Four `(u32 offset, u32 count)` header pairs. Record sizes are 16, 16, 20 and 16 bytes. |
| `.chk` | One 16-byte header per paired BLK event. Each header holds two `(u32 offset, u32 count)` pairs; offsets are absolute from the CHK payload start. Each list contains 16-byte records. `FFFFFFFF/FFFFFFFF` marks an absent list. |
| `.ttk`, `.ikt`, `.spn`, `.que`, `.def` | Exact decoded bytes are preserved. Complete field semantics remain under analysis. |

BLK tables 0 and 1 each contain a child offset at byte 4 and child count at byte 8. The offset is relative to the next table's start. Table 2 contains an operation count at byte 6 (u16) and operation offset at byte 8 (u32), relative to table 3. All these child spans validate across all 115 programs.

Native address `0x020551B8` selects entries using the first three tables. It compares current context values and calls condition functions. It does not walk all text in order. Original debug strings identify table 1's u16 at byte 0 as `BlockID` and u16 at byte 2 as `NowTime`. Table 2's u16 at byte 0 is `ModeID`. Its signed u16 at byte 4 is `TruthEventID`, also used as the debug event key and CHK header index. `OriginalEventSelector` transcribes the mode-specific comparisons and normal/system differences. `OriginalEventSession` implements condition commits and saved-context restoration. A Ghidra listing omitted the fifth selector input in a closeup branch. The Swift version preserves that subarea argument from the ARM instructions, tested with the actual nonzero subarea in `EP10_R108`.

The text loader at `0x02054DF4` reads the count, sets the offset-table pointer to payload plus four, adds `count * 4`, and resolves each relative string offset. This independently confirms the indexed-text layout.

`EP3_R209.txt` is a useful fixture: decoded size 11,103, count 578, string-data base 2,316, and its first offsets are 0, 31, 32, 33 and 55. Its first record contains control codes rather than visible dialogue. Do not strip controls or display entries in index order as a replacement for the game's event logic.

## Original operation dispatcher

The original update routine starts at `0x0203BC9C`. At `0x0203BE7C`, it addresses a 16-byte operation using the current operation index. It reads the opcode as a **single byte at offset 0**. At `0x0203BEB4`, it dispatches values 0 through 53 through the ARM branch table at `0x0203BEC0`.

`dispatch.json` records all 54 verified branch targets, their observed counts in the decoded programs, and one original byte fixture for each used opcode. This is a map of native handlers, not a claim that every handler's semantics are understood.

| Opcode, decimal | Native handler | Confirmed behavior and limits |
| --- | --- | --- |
| 4 | `0x0203C420`, calls `0x0203F57C` | Reads the indexed-text ID from u16 at byte 10. `OriginalDialoguePacket` recovers three consecutive lines, or six lines for a paired display. It preserves character, animation and text controls. Rendering, waits and animation phases remain separate controller work. |
| 11 | `0x0203C450` | Stores u16 at byte 2 as a wait limit. No instance occurs in these 115 BLK programs. |
| 12 | `0x0203C48C`, calls `0x02097804` | Sets the selected bit in the 64-bit bank based at game-state offset `0x32`. The original representation uses one 16-bit slot per eight bits. IDs greater than or equal to 64 are ignored. Story names for these bits are not established. |
| 18 | `0x0203C558` | Byte 2 equal to zero clears the bit; nonzero sets it. The ID is u16 at byte 4 in the 256-bit bank based at game-state offset `0x852`. Calls `0x02097D90` or `0x02097DDC`; IDs outside 0 through 255 are ignored. |
| 29 | `0x0203C868` | Removes the item whose ID is the low byte of u16 at byte 4, if present. The ordered inventory shifts left and its count decreases. This operation preserves the item's separate state byte. |
| 30 | `0x0203C894` | Adds the item whose ID is the low byte of u16 at byte 4, if absent and the inventory has capacity. A zero item-state byte becomes one. |
| 35 | `0x0203C49C`, calls `0x02097840` | Clears the same 64-bit-bank bit as opcode 12. |
| 49 | `0x0203CA34` | Removes the item using the low byte of u16 at byte 2, then clears its separate state byte using that field interpreted as signed u16. The state setter only accepts IDs 0 through 87. |

Common advancement is not always one operation. `0x0203CE28` first tests the advance flag at controller offset `0x8C`. A helper at `0x0203FE98` can process animation lookahead. At `0x0203CE70`, an operation whose byte 1 equals 2 advances by two records; other records advance by one. The dialogue handler can clear the advance flag and manage the index during its own state transitions.

The dispatch catalog counts raw records, including paired metadata. Traversing each event with the paired-record rule gives 22,369 executable commands, including 17,074 dialogue commands and 2,741 two-page dialogue pairs. All actual second records in those pairs use opcode 4 and a text index three higher. Scanning every raw record as a command start produces misleading pairs.

Wait timing is also explicit: `0x0203BDE4` tests a nonzero wait limit at controller offset `0x24`. It increments the elapsed counter at offset `0x20` while `counter <= limit`; otherwise it clears both. Either branch returns from that update. Starting from zero, a positive limit blocks `limit + 2` subsequent controller updates. This must not be replaced with an assumed duration in seconds.

These observations support isolated native decoder and state tests. They do not yet establish a complete event interpreter. Unknown operations and unverified controls must stop execution, with their original byte offsets retained for investigation.

The original ordered inventory has 88 bytes at game-state offset `0x44`, with count at `0x9C`. Its separate item-state array has 88 bytes at `0x9D`. The add helper at `0x02097914` checks the capacity, avoids duplicates and calls the state getter at `0x02097EB0`; that getter has no item-ID bounds check. Every observed add/remove operation uses an ID below 88. A native implementation should reject other IDs instead of reproducing an out-of-bounds read. Remove helper `0x0209798C` receives the index found by `0x02097A80`; the latter returns -1 when absent.

Useful original inventory fixtures are `EP10_R108.blk` offset 3984 (`1dff00004d0000000000000000000000`), `EP10_R205.blk` offset 1876 (`1eff01003b0000000000000000000000`) and `EP10_R108.blk` offset 4112 (`31ff4d00000000000000000000000000`). These are opcodes 29, 30 and 49 respectively.

## Condition records

The drive-condition evaluator starts at `0x02029254`. It indexes the first CHK header pair with the signed event key. Key -1 (`FFFF`), an absent first pair, or an empty list passes. A missing CHK payload fails. The type is a **signed byte at record offset 0**, loaded at `0x020292F4`.

For the condition types below, a false result returns immediately. Invert equal to zero requires the underlying state to be true. Any nonzero invert requires it to be false. The offsets are within a 16-byte condition record.

| Type | Fields | Original state read |
| --- | --- | --- |
| 0 | u16 group at 2, u16 flag at 4, s8 invert at 6 | Event flag, `0x0202973C` to `0x02098038`. Group and flag become signed 16-bit values; valid ranges are 0–46 and 0–255. State bytes start at `0xD15 + group * 32`. |
| 1 | u16 ID at 2, s8 invert at 4 | 64-bit game-flag bank, `0x020297A8` to `0x020977CC`. |
| 5 | u16 ID at 2 (low byte), s8 invert at 4 | Ordered inventory contains, `0x0202980C` to `0x020979F4`. |
| 6 | s8 invert at 2, u16 door ID at 4 | Door state, `0x02029878` to `0x02097C2C`. Reads signed 16-bit state at `0x110 + ID * 2`; nonzero is true. |
| 8 | s8 invert at 2, u16 ID at 4 (signed) | Trick bit, `0x02029964` to `0x0209863C`. Bit bank starts at `0x872`. |
| 7 | s8 invert at 2, s16 keyword at 4, u16 person at 6 | `0x020298D4`. Person `FFFF` reads byte `0x881 + keyword*4`. Otherwise it tests the person's bit in signed u16 at `0x882 + keyword*4`. |
| 10 | s8 invert at 2, s8 memo at 3 | `0x020299D0` reads a bit from bank `0x13D0`. |
| 14 | s8 invert at 2 | `0x02029A68` tests whether state byte `0x137F` is nonzero. |

The terms event flag, game flag, item, door, keyword, memo and trick are backed by debug strings referenced by these exact helpers. Type 11 compares signed byte 3 with the first game-state u16. Equality passes only when byte 2 is zero. Inequality passes only when byte 2 is exactly one. Type 12 tests the external process byte at `0x02107739` for zero. Unavailable external state remains unresolved.

Type 13 compares byte `0x1380` with signed u16 at record byte 2. Signed u16 at byte 4 selects equal (0), greater (1), or less (2). Other comparison values retain the previous result. Failure continues to the next record. Success commits and returns immediately. An unhandled type, including the original kinds 2 and 4, returns the previous result immediately without a commit. That result starts as true. These rules are confirmed at ARM addresses `0x02029508` through `0x02029584` and covered by original-record tests.

The evaluator calls `0x02028268` after every successful recognised check, updating selection fields at session offsets `0x2A`, `0x28`, `0x26`, `0x40` and byte `0x44`. Thus an earlier check can commit even if a later check fails. Key -1 and an absent list also commit. An empty list passes without a commit. `OriginalConditions.evaluate` preserves those calls through an explicit callback. `OriginalEventSession.evaluate` applies the actual field changes.

The second CHK pair contains event-exit transitions consumed by `0x0203D61C`. A type-zero record supplies mode from byte 2, scene from u16 at 4, block from u16 at 6, and event from u16 at 8. The next operation index is zero. Mode 15 selects a record using the embedded process return index. `OriginalEventCompletion` implements the verified simple exit paths. Other modes still need their original UI, animation and keyword handlers. Normal-script completion also sets the event bit in both banks `0xD15` and `0x14CC`, through `0x02097FC0`.

For example, `EP1_R213.chk` offset 2096 contains `06ff01ff2000ffffffffffffffffffff`: type 6, nonzero invert, door ID 32. `EP4_R201.chk` offset 2304 contains `08000100310000000000000000000000`: type 8, invert 1, trick ID 49. The parser checks all 115 CHK files against their paired BLK event counts.

## Chapter 1 and remaining work

The earliest recovered Chapter 1 debug label is `01-1700-0010-0010`, key 0 in `EP1_R102.dbg`. That program has 12/20/90/902 records across its four tables. This identifies an original event but does **not** prove it is the game's boot entry. Boot/title setup and the initial event context still require tracing.

The complete reset at `0x020989EC` clears the first `0x3558` state bytes and three notebook canvases of `0x1800` bytes, then calls `0x02097544`. The latter initializes the inventory, flag banks, person fields, door defaults, object visibility, and timestamp. Door defaults come from `data/map/sdata/door_flg.bin`, with 50 records. Object defaults come from `onoffobjs.dat`, with 84 records. The Swift `OriginalGameState.newGame` matches **all 32,088 bytes** of the original `boot120-ram.bin` game-state snapshot, including the source clock result of one. The memory starts at `0x0211018C`. An isolated initializer call preserves untouched fields, as the original does.

`OriginalStateCommand` additionally transcribes state effects for opcodes 10 (subtypes 1 and 2), 19, 23, 25, 33, 37, 39, 40, 42, 46 and 51. Opcode 19 returns an explicit door-42 controller notification. These state writes do not replace controller animation lookahead or UI state. Invented story names have not been assigned to unknown fields.

The title update at `0x0200D27C` selects process 114 for a new game. That process has constructor `0x0201094C`, initializer `0x020109B4`, and update `0x02012DD4`. The opening queue has been captured by the reference runner. This is separate from proving the later handoff into normal chapter events. The first `EP1_R102` narrative record transitions to mode 15, event 1. That row launches process 56 (`byte16 + 23`). Its factory passes **slot 30** to `0x0200B2D8`; the table at `0x020E92A4` maps this to **overlay 31** and the entrance constructor `0x021FCB40`. Slot numbers are not overlay IDs. The reference runner reaches this exact process after the opening, and the loaded bytes match overlay 31. Its resources are `entrance.wpf` and the original R101 model. The event table alone must not be treated as proof of boot order.

`tools/recover_original_runtime_tables.py` exports the 36 original music names and sequence IDs and all 197 sound codes. `0x0200AD94` returns record field 8 first and field 4 second. `runtime-tables.json` retains those exact output positions plus source addresses and hashes.

The remaining native rewrite includes startup and chapter transitions; all condition and flag-bank meanings; script controls and branches; original render ordering, map collision and movement; character timing and animation transitions; original puzzle state machines and story gates; audio cues; notebook behavior; save data; endings and failure paths. The original game must be compared at these boundaries, including closed/open hinge transitions. No placeholder corridor, invented dialogue, arbitrary initial inventory, guessed chapter shortcut or simplified puzzle can establish equivalence.

An emulator could execute the original logic, but it is outside the user's chosen architecture. The native implementation must recover these systems and keep the Duo book presentation around the verified behavior.

## Native entrance process

`OriginalEntranceProcess` transcribes process 56 from overlay 31. The separate update (`0x021FD388`) and draw (`0x021FD5A8`) preserve the original capture/upload cycle. The approach routine moves the actor from `(512, 12288, 30648)` to `(512, 12288, 24018)` through 255 steps of 26 fixed units; the final pose and waiting stage match the original RAM capture. The handle rectangle at `0x021FE1D4` is inclusive `[150, 84, 200, 101]` after the original handedness transform. In right-handed raw DS coordinates, the valid touch is x55–105/y84–101. A centre tap therefore does not open the door.

A valid new press requests sound archive 51/entry 0, optional rumble 1, and process return 0. The model animation advances by 0.75 each update. When it exceeds frame 40, both screens begin the original 100-update fade. Native effects retain the original fade mode and mask rather than assigning an unverified visual interpretation. The process waits for actual fade completion, then delays 100 updates and emits manager statuses 1 and 3. The final movement tick intentionally does not commit its local actor position, matching the source early return. All local counters and image stages are Codable for book closure.

The native scene host still needs to apply the source resource loads, camera/rendering, fades, sound, and shared resource lifecycle calls. The state machine does not replace those with placeholder graphics or assume an unavailable renderer has completed a fade.

## Chapter 1 counter bell and Dunning's arrival

After lobby event 2, the next `EP1_R102` story path is event 3 (closeup), event 4 (process 24), events 5, 6 or 7, then event 8 (Dunning) and event 12. The native runner now plays events 3 to 12. It stops in event 12 at operation offset 3912, opcode 10 kind 5.

### Search view look

The search process (process 0x93, update `0x0203148C`) writes the closeup context. Phase 1 (`0x02031760`) handles input. Phase 2 (`0x02031944`) writes the talk session and requests the talk controller, process 0x7D.

| Step | Address | Behavior |
| --- | --- | --- |
| Initialize | `0x02030B04` | Reads the area from message 0x2F into +0x0C. Loads `data/MAP/sdata/<map>.srh` and `.upv`. Allocates a new talk session (`0x02028160`). Sets +0x30 and +0x32 to -1. |
| Touch | `0x0203314C` | On a release (`0x0209AF40`), `0x02033528` reads the picked model node name. A name `objNN` gives subarea NN in +0x44. |
| Up-view test | `0x020331A8` | Calls `0x020B462C(srh, area, subarea)`. Values from 0 to 0xFFFE, with a valid `0x020B4A80` record, select case 2 (up view). Other values select case 0 (look). |
| Look | `0x02031A0C` | Scene 0xFFFE (`0x02028240`). Mode 10, event 0 (`0x02028360`). Block 0, area +0x0C, subarea +0x44 and upView `ldrsh [+0x32]` on the stack (`0x0202847C`). Next process 0x7D. |

The `.srh` layout is: u16 area count, u16 second count, 20-byte area records (u16 area, u16 entry count, 16-byte model name), 24-byte records, then 8-byte entries (u16 subarea, u16 upView ID). The pointer setup at `0x020B45E4` gives this layout. 37 of 41 tables end exactly after the entries. R119, R123, R126 and R304 have more bytes; these are kept but not interpreted.

`R102.srh` area 2 is `R102_03`. Its subarea 2 entry has upView 0xFFFF, so the look branch is taken. The search model `map/R102/R102_s02/R102_s02.mdf` contains node `obj02`. Thus the bell look context is: scene 0xFFFE, mode 10, event 0, block 0, map 2, area 2, subarea 2, upView -1. Event 3 (`0a00 0300 0300 … 0202 0200`) matches it: packed map 2 and area 2 at byte 16, subarea 2 at byte 18. Its CHK condition requires event flag (2, 7) clear.

Event 3 has mode 10. Completion `0x0203E7C8` applies its CHK exit (mode 15, scene 0xFFFE, event 4) at once. For an exit mode other than 15, it also starts a fade and a sound. Without an exit, the closeup returns to the search view; that path is not recovered.

The map walk that opens search area 2 and the 3D search view that picks `obj02` are not recovered. These are the blocking systems for normal play.

### Process 24: the bell

Event 4 has mode 15 and byte 16 = 1, so process 24 runs. Factory `0x0200B334` case 0x18 passes slot 0x20 to `0x0200B2D8`. The table at `0x020E92A4` maps it to overlay 32, constructor `0x021FCB40`. The object size is 0x46C. Resources are `/data/trick/bell.tbl` and `bell.wpf` with `bell01.bin` and `bell02.bin`. `OriginalBellProcess` transcribes it.

| Item | Address | Behavior |
| --- | --- | --- |
| Update | `0x021FD0A8` | Stage +0x2AE. Stage 0 runs `0x021FCBEC`, then enables all trick buttons. Stage 1 runs the ring machine. Stage 5 waits for the screen-0 fade, writes result 0 and returns 2. |
| Ring machine | `0x021FD478` | A bell touch sets +0x43E to 2 and counts a ring in +0x448. The swing uses +0x440 × `0x3CAC0831`, then sound archive 37, entry 0. After 3 rings (+0x44A), it starts a fade, disables touches and buttons, plays archive 1, entry 0, and after 130 updates sets stage 5. |
| Bell touch | `0x021FE3AC` | A new press inside the inclusive rectangle at `0x021FE7F8` (x′ 56–96, y′ 72–120), or on a nonzero `bell01.bin` pixel at index y′ × 256 + 255 − x′. Coordinates use the handedness transform at `0x02009920` and `0x02009960`. |
| Quit | `0x0202778C`, `0x020267F0` | Button slot 5, x′ 228–252, y′ 156–188, when enabled. Plays archive 8, entry 2, fades screen 0, and sets +0x43C to 1. After the fade, the result is 1 and the update returns 2. |
| Result | `0x02026E68` | The trick base writes through its +0x288 pointer, which message 0x1F supplies. The talk controller reads it as the process return. |
| Hint request | `0x021FE468` | +0x466 values 1 and 2 write mode 20, pair (1, value) (`0x020282A4`) and request the talk process. Only update stages 2 and 3 set +0x466, and no code in overlay 32 enters them. The native host stops if a request occurs. |

`bell01.bin` and `bell02.bin` are 8-bit linear bitmaps. After 16 zero bytes, the header holds width 256, height 192, width, height, kind 4, 256 colours and palette offset 0x20. Pixels follow at 0x220. The mask pointer at `0x021FCBEC` (base + u16 0x1C + u16 0x1A × 2) confirms the offsets. `bell01.bin` has 5,412 nonzero pixels. The draw at `0x021FD7B4` puts `bell01` (rotated by +0x444) and `bell02` on the 3D screen.

Process returns 0, 1 and 2 select events 7, 5 and 6. Events 5 and 6 contain only opcode 21 with kind 5. The dispatcher sends opcodes 15, 17, 21, 32, 41 and 45 to `0x0203C4AC`, which pushes (s8 byte 2, s16 at byte 4) on the request stack at `0x021046B8` (push `0x020971D0`). Opcodes 52 and 53 push kinds 10 and 11. Opcode 16 also compares a string and is not transcribed. The search process consumes kind 5 at `0x020340D0` and reloads its view. Result 2 is not produced by any recovered overlay-32 path.

### Opcodes on the path

Opcode 9 (handler `0x0203C474`) calls `0x020401EC`. That function only stores 1 at controller +0x8C and returns 0. The dispatcher already stored the same value, so opcode 9 advances like other records. Opcodes 6 (`0x0203FBFC`) and 8 (`0x0203FD30`) do not occur on this path.

Event 7 (mode 3, scene 0xFFFE) exits to scene 2, event 8. Event 8 exits to event 12. Event 12 ends with opcode 10 kind 5 at offset 3912. That handler (`0x0203C5CC`) passes each listed object record to `0x0204B728` and saves the session frame (`0x02028564`). On a second pass it writes 0 for each listed ID with `0x02097C80`, the helper that kind 2 also uses. It needs controller state that is not recovered, so play stops there.

## Conversation systems

### Event end and saved frames

After every event the talk process calls `0x020544BC`, which calls `0x020283B0`. If session +0x2D8 (override) is zero and a frame is saved, the last frame is popped and committed, and +0x2DA becomes 1 unless the previous mode was 5. Otherwise the result is the commit byte +0x44. A true result selects again; a false result ends the talk. A push (`0x02028564`) sets the override, so the first restore after a push only clears it. Event setup (`0x0203A444`) clears +0x44 (`0x02028470`) after selection. If no event is selected, setup sets +0x14 to 3 and the talk ends.

### Choice prompt

Opcode 10 kind 5 (`0x0203C3E8`) pushes the frame (block, mode, event, operation + 1), marks each listed ID with `0x02097C80`, and enters UI state 0x6F with +0x64 = 2. KIF records give the label (48 bytes), the mode-5 event ID (field 0) and the option ID (field 3). State 0x6F (`0x0203CE9C`) writes mode 5 and the event with `0x0202824C`.

### Item opcodes

Opcode 6 (`0x0203FBFC`) adds the item in u16 2 with `0x02097914`, then opens a text window at the line in u16 8 for the number of pages in u16 10. Opcode 8 (`0x0203FD30`) stores a picture ID and selects picture state 0x13 or 0x14. It writes no game state, but waits for a child process. The native runner now blocks here. See [Touch pictures](touch-pictures.md).

### Mode setup and completion

`0x0203B0A8` starts each event by mode. Mode 1 marks the keyword in u16 0x12 as asked by the partner (`0x02098440`, which replaces the mask). Mode 3 skips all operations if every type-3 CHK record's ID is already marked (`0x02097CC4`). Modes 7 and 8 read type-2 records: s16 4 is a keyword and u16 2 is the menu block (+0x66).

The partner (+0x0C) is the session scene ID when it is not 0xFFFF, 0xFFFE or 0xFFFD. In `EP1_R102`, scene 2 holds Dunning's events and person 2 is Dunning.

`0x0203D61C` ends modes 0 and 1 with the CHK exit, or reopens the menu while topics remain and the partner's nibble at 0xD0C is positive. Mode 1 then runs `0x02055CF0`: a keyword is used (0x881) when a flag-1 person was asked, or when all flag-3 people were asked. Mode 7 reopens the menu only if an open topic is also one of its type-2 records; otherwise it follows its exit. Mode 8 always opens the menu. Mode 2 follows its exit.

### Question menu

The chapter `.ttk` file holds 0x80-byte records: label (0x00–0x5F), keyword ID (u16 0x60) and one flag per person (0x70 + person). A first byte of 0xFF ends the table. A topic is listed if it is available (0x880), not used (0x881), not asked by the partner (0x882 mask) and flagged for the partner. A topic answer selects mode 1 with the keyword in session +0x38 (`0x020282D8`), in block +0x66 when it is set (`0x02028350`). Leaving selects the mode-4 event that `0x020295B0` finds in the partner's scene and that block.

### Interrupts

`0x020401FC` runs with the record after each dialogue command. Opcode 5 calls `0x0204033C`: if opcode 9 is two records after the page, it arms the interrupt (+0x96), clears +0x94, and stores the block (+0x98) and opcode 9's event (+0x9A). Opcode 38 sets +0x94. Text state 0x10 (`0x0203D3B8`, reached through the jump table at `0x0203CEF4`) handles a press (+0x70 > 0): it pushes the current page, selects mode 6 with `0x02028268(+0x98, 6, +0x9A, 0)` and ends the event. It disarms when +0x94, a press or +0x95 is set. While session +0x2DA is set, the dispatcher skips non-dialogue opcodes, and `0x0203F57C` skips pages that start with `%!` or `%?` until the replay rule shows a page and clears the flag.

## Process 25: the registration card

The factory case 25 passes slot 0 to `0x0200B2D8`, which maps to overlay 1 (`CSign`). Update `0x021FCFEC` waits 30 updates, then reads held touches (`0x021FD234`). A touch that moves right by more than one pixel inside an unfilled field fills it. Field rectangles are at `0x021FE708` (x), `0x021FE718` (y), `0x021FE700` (width) and `0x021FE710` (height), in `0x02009920`/`0x02009960` coordinates. Strokes grow by two per update up to the widths (`0x021FD344`), with sound archive 25, entries 0 to 3. When all four fields are filled, the process waits 120 updates and returns 0. The quit button returns 2 if fields 0 to 2 are blank, else 1. `signnote.bin` is the blank card and `signnote02.bin` the completed card.
