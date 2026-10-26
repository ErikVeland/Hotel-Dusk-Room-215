# Paperback cover material

The closed display uses `Sources/HotelDuskDuoKit/Resources/Images/Cover/HotelDuskPaperback.png`, a material treatment of the supplied cover made with the built-in image generation tool on 16 October 2026. The supplied `HotelDuskCover.jpg` is retained unchanged. This derived cover is presentation artwork for the port, not an extracted original game asset.

The cover fills the display. No UI text or badges are drawn over it. The existing title is part of the print. Its digital glow is replaced by faded red ink. Wear is baked into the cover so it does not shimmer or change when the hinge moves.

## Interior notebook materials

The open book uses the Metal passes in `Metal/BookPaper.metal` for warm wood-pulp paper, edge oxidation, sparse foxing, photo mounting card, and translucent adhesive tape. Two stable tape seeds produce different torn ends. Paper, card, and tape render once and remain cached. Only hinge lighting responds to page movement, with the existing finite settling animation and Reduce Motion support.

`NotebookPhotograph` mounts exploration, inspection, notebook, chapter, and puzzle images on cream card with narrow shadows and two tape strips. The mount sits outside the image bounds. Only the backing card tilts; gameplay pixels and their touch targets remain aligned. Each image reserves space for the mount within its page. Decorative layers ignore input and accessibility.

The title leaf combines oxblood Baskerville lettering, Courier labels, and a pasted reproduction of the existing cover. The touch page carries a small “FIELD NOTES” running header. Source game artwork and dialogue retain their original colours and content.

Material tests check deterministic grain, tape transparency, torn edges, and opaque card stock. Layout snapshots cover the title, pause menu, and live lobby at landscape and narrow portrait sizes.

## Written dialogue

Dialogue accumulates as one session-owned transcript across the physical book. Short source rows reflow into paragraphs from the top-left margin. Georgia glyphs appear progressively, filling the left leaf before continuing onto the right. Completed passages stay in place. Core Text measures and draws the same text, including long passages that cross leaves and spreads. Original screen IDs and gameplay handedness do not change reading order.

A tap finishes the current ink. Once both leaves are full and more text is available, the next tap turns to a new spread. Dialogue cannot advance during a turn or skip unread overflow. iOS uses UIKit's native double-sided page curl with a central spine. Desktop uses a curved, textured sheet with a reverse face and moving shadow. Reduce Motion and VoiceOver show the ink immediately; Reduce Motion also removes the turn animation. Pausing, closing the book, and leaving the app stop the writing. Reading positions survive view remounts, page swaps, and window or text-size changes within the play session.

The notebook keeps the original wording, emphasis colours, and dialogue acknowledgement logic. Control-only packets do not add blank paragraphs. Retained notes remain visible on otherwise unused pages during questions and puzzles. Starting or loading a game creates a new transcript; it is not part of checkpoint saves.

## Generation prompt

Use case: style-transfer.
Asset type: production full-bleed front-cover texture for a phone that becomes a paperback when closed. Edit the attached original Hotel Dusk cover.
Primary request: make this look like the actual, very weathered thin cardstock front cover of a 1970s pulp mystery paperback dug out of a second-hand bookshop dime bucket. Photorealistic physical print and damaged paper material, not a videogame poster with a noise overlay.
Keep the exact source illustration composition and character identities, faces, door, title position and title words "HOTEL DUSK" / "Room 215". Retain the source illustration as printed artwork. Remove the digitally glowing halo and glossy bevel from the title: it is faded, slightly misregistered oxblood red ink on old matte stock, with its original serif letterforms.
Materials: oxidised warm ivory paper showing through abraded black ink; irregular rubbed-off ink at edges; substantial natural binding creases along the left edge; worn scuffed matte surface; visible cheap paper fibres and subtle halftone printing; several authentic diagonal cover creases with tiny exposed paper cracks; a bent softened lower-right corner; faint handling grime and sparse brown foxing; patchy sun-faded charcoal blacks. Decades of use, convincing and irregular, not decorative grunge lines.
Composition: perfectly flat front-on scan, portrait 2:3 aspect ratio, cover surface extends to ALL FOUR image edges. All pixels belong to the book cover. No margins, desk, background, device, surrounding scene, drop shadow, three-quarter perspective or mockup. No extra text of any kind, author name, subtitle, logo, label, sticker, price or watermark. Preserve readability of the existing title. High detail, tactile, restrained warm sepia ageing with faded dark red title.
