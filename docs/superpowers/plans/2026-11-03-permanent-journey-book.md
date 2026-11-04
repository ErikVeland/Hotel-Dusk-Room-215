# Permanent Journey Book Implementation Plan

> **For agentic workers:** Use superpowers:executing-plans to implement each task in this chat.

**Goal:** Keep the narrative and the player's chosen route in one permanent, saved book.

**Architecture:** Journey leaves use unique markers within the existing ink stream. Saved records hold frozen pencil views, route points and portrait references. The layout places journey leaves between dialogue pages without changing the existing reading-cursor model.

**Tech Stack:** Swift, SwiftUI, Core Graphics, Core Text, ImageIO, XCTest.

**Spec:** `docs/superpowers/specs/2026-11-03-permanent-journey-book-design.md`

## Global Constraints

- Keep portraits in the outer corners and preserve fixed text clearances.
- Capture actual movement and source artwork. Do not invent game narrative.
- Preserve old save compatibility and the existing engine's event order.
- Append journey records and route points in incremental saves.
- Do not record restore replay twice.

## Review Focus

- Repeated visits must receive distinct identities even without intervening dialogue.
- Starting an interaction must capture the walking view before the scene changes.
- Stale asynchronous renders must not replace the saved pre-interaction view.
- Repeated marker positions must not make bookmarks ambiguous.
- Long playthrough saves must append new images rather than repeat old image payloads.

### Task 1: Saved journey records

Create `Models/BookJourney.swift` and `Tests/HotelDuskDuoTests/BookJourneyTests.swift`.

- [x] Test ordered visits, movement sampling, immutable capture records and incremental deltas.
- [x] Implement Codable journey entries, active visits, portrait references and append-only deltas.
- [x] Check decoding of old notebook saves with no journey record.

### Task 2: Mixed book pages

Modify `Models/DialogueNotebook.swift` and `Renderer/DialogueNotebookLayout.swift`. Create `Renderer/JourneySketch.swift`.

- [x] Test journey markers between passages, complete pagination and unchanged earlier ink.
- [x] Add a journey leaf marker to the ink stream and constrain dialogue frames at markers.
- [x] Draw source-derived pencil views and a route over the recovered floor plan.
- [x] Resolve historical portrait references by passage range.

### Task 3: Engine capture

Modify `Engine/OriginalPlaySession.swift`.

- [x] Test arrival, movement, interaction, departure and repeat visits through real session inputs.
- [x] Capture the room view before inspection, conversation or a walking event replaces it.
- [x] Sample actual world positions and commit journey boundaries in reading order.
- [x] Keep replay capture disabled until the saved book is restored.

### Task 4: Save integration

Modify `Engine/Original/OriginalResumeSave.swift`, `OriginalChapterSave.swift`, `OriginalPlayProgress.swift` and `OriginalInstantSaveLog.swift`.

- [x] Test walking, interaction and chapter save round trips, including old saves.
- [x] Carry book state in walking and chapter saves without enlarging replay bases.
- [x] Append journey and route deltas in the instant-save log.
- [x] Validate source offsets and route coordinates before accepting a saved record.

### Task 5: Book presentation and verification

Modify `Views/Components/NotebookDialogueView.swift`, book-history labels and relevant snapshot tests.

- [x] Show journey artwork in the same page-turn system and retain historical portraits.
- [x] Render route/sketch pages and compare earlier pages after new movement and dialogue.
- [x] Run focused journey, dialogue, save and curl checks.
- [x] Build the iOS simulator target and inspect the rendered book.
- [x] Update the README with verified behaviour and any remaining limits.


## Implementation record — 4 November 2026

The implementation adds `BookArtworkStore.swift` to keep each drawing once beside a resume save. Checksums use the drawing digest, so routine saves do not encode the entire image collection. A save backup must include `book-art`.

The current walk is committed when the player opens the earlier pages. In-game retries and recovery preserve the current book and start another visit. Explicit new games and older-save loads retain their reset/load meaning. Historical portrait frames resolve through a bounded synchronous cache so they also appear on page-curl snapshots. Empty portrait spaces are recorded explicitly.

### Verification

- 85 distinct focused Swift checks passed. These cover journey leaves, unchanged earlier ink pixels, recorded portraits, selected answers, walking and interaction saves, native chapter save/restore, incremental files, artwork integrity, legacy saves, recovery, page geometry and page turns.
- 27 verification-tool tests passed, including embedded drawings, external drawing references and missing artwork.
- The iOS simulator build passed.
- Room-and-route and live-interaction reference previews were rendered and inspected.
- `git diff --check` passed.

### Broader verification limits

`OriginalResumeSaveTests/testEveryOpeningStepSurvivesASeparateSession` fails at the bell-awaiting-touch and signed-registration assertions. The same two assertions failed when `OriginalPlaySession.swift` was temporarily replaced with its HEAD version, with only a no-op compatibility method for the new recovery hook. The source was restored after that comparison. This check was excluded from the final focused passing run. The comparison covered the original engine file, not an isolated build of the entire earlier tree.

`OriginalGameOverTests/testBackToTitleLeavesResumeCheckpointUntouchedAfterDroppedCrowbar` and `testRetryRestoresTheSourceCheckpointAfterDroppedCrowbar` could not read `extracted/reference/chapter-two-crowbar-closeup/torn-ram.bin`.

The four original chapter-save reference checks skipped because their captured RAM fixtures were unavailable. The new native chapter save/restore check uses an ordinary generated chapter checkpoint and passed without those fixtures.

The complete Chapter 1-to-ending route was not rerun for this change. Permanent content and artwork survive scene changes. Display dimensions and text-size changes can still repaginate the book.
