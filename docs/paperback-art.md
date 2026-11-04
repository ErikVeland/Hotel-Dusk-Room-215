# Paperback cover material

The closed display uses `Sources/HotelDuskDuoKit/Resources/Images/Cover/HotelDuskPaperback.png`, a weathered treatment of the supplied cover. The supplied `HotelDuskCover.jpg` is retained unchanged. This derived cover is presentation artwork for the port, not an extracted original game asset.

The cover fills the display. No UI text or badges are drawn over it. The existing title is part of the print. Its digital glow is replaced by faded red ink. Wear is baked into the cover so it does not shimmer or change when the hinge moves.

## Interior notebook materials

The open book uses the Metal passes in `Metal/BookPaper.metal` for warm wood-pulp paper, edge oxidation, sparse foxing, photo mounting card, and translucent adhesive tape. Two stable tape seeds produce different torn ends. Paper, card, and tape render once and remain cached. Only hinge lighting responds to page movement, with the existing finite settling animation and Reduce Motion support.

`NotebookPhotograph` mounts exploration, inspection, notebook, chapter, and puzzle images on cream card with narrow shadows and two tape strips. The mount sits outside the image bounds. Only the backing card tilts; gameplay pixels and their touch targets remain aligned. Each image reserves space for the mount within its page. Decorative layers ignore input and accessibility.

The title leaf combines oxblood Baskerville lettering, Courier labels, and a pasted reproduction of the existing cover. The touch page carries a small “FIELD NOTES” running header. Source game artwork and dialogue retain their original colours and content.

Material tests check deterministic grain, tape transparency, torn edges, and opaque card stock. Layout snapshots cover the title, pause menu, and live lobby at landscape and narrow portrait sizes.

## Written dialogue

Dialogue accumulates as one session-owned transcript across the physical book. Short source rows reflow into paragraphs from the top-left margin. Georgia glyphs appear progressively, filling the left leaf before continuing onto the right. Completed passages stay in place. Core Text measures and draws the same text, including long passages that cross leaves and spreads. Original screen IDs and gameplay handedness do not change reading order.

A tap finishes the current ink. Once both leaves are full and more text is available, the next tap turns to a new spread. Dialogue cannot advance during a turn or skip unread overflow. iOS uses UIKit's native double-sided page curl with a central spine. Desktop uses a curved, textured sheet with a reverse face and moving shadow. Reduce Motion and VoiceOver show the ink immediately; Reduce Motion also removes the turn animation. Pausing, closing the book, and leaving the app stop the writing. Reading positions survive view remounts, page swaps, and window or text-size changes within the play session.

The notebook keeps the original wording, emphasis colours, and dialogue acknowledgement logic. Control-only packets do not add blank paragraphs. Retained notes remain visible on otherwise unused pages during questions and puzzles. An explicit new game starts a new transcript. Resume saves retain the supported transcript and journey state.
