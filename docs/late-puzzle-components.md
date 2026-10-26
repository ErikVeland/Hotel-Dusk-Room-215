# Later puzzle components and map coverage

These checks establish individual components. They do not establish an uninterrupted
playthrough of Chapters 6–10 or complete presentation fidelity.

## Cashbox, process 80

The cashbox shares overlay 10 wheel motion with process 31. Its source target is
518, its retained value is stored separately at game offset 0x13DE, and its success
path returns without the office cabinet's drawer sequence. The host selects the
original cashbox dial and cabinet textures.

`tools/capture_cashbox_component.py` requests process 80 in an isolated original
walking checkpoint, then turns each wheel with stylus input. It does not write a
puzzle outcome or instance field. `Tests/Fixtures/Cashbox/source-trace.json` retains
15 original states and the ROM/input hashes. The native test compares angles,
positions, selections, return values and targets against these states. A separate
native test enters the original Chapter 10 event and solves the wheels through the
session's touch API, verifying puzzle flag 56 and the retained value.

## Coin cross, process 51

Overlay 18 supplies the six initial positions, circular picking, snapping grid,
two accepted stacked-coin arrangements, explicit Check action and return values.
The source depth sort at ARM9 0x020CD2C8 changes the order of equal-depth coins;
the native port preserves that ordering so overlapping coins can be picked again.

`tools/capture_coin_component.py` records original pickup, motion, release and a
successful Check. The compact fixture in `Tests/Fixtures/Coins/source-trace.json`
includes command hashes and exact fixed-point coordinates/depths. Native regression
checks match those states and the success return. Other tests distinguish a wrong
answer (1), abandonment (2) and success (0). The Chapter 6 source-event test drives
the native screen through touch and verifies puzzle flag 27.

Both components draw supplied original artwork. Their complete visual presentation,
including supporting character reactions, still needs comparison with the original.

## Walking and inspection maps

The map catalog now includes R123, R301, R302 and R304, bringing the walking-map
render check to 41 rooms. Original collision files and source hashes are bundled.
The late-room test also loads every named search scene and its camera markers.

Four model materials are not bound by their source `.def` texture lists:
R123/r123_lamp02, R301_s01/denjou, R302/noicon and R304_s02/yuka01. Source texture
lookup 0x02083A6C returns -1 for an unbound name; 0x0208B6F0 uses the fallback bank
instead. These explicit materials now use the renderer's untextured path rather
than failing the whole room or borrowing another material's image. A full original
pixel comparison for these rooms remains outstanding.
