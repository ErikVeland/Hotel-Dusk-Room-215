# Permanent journey book

The book records the game narrative and the route that the player chooses. Each visit to a place belongs in the record. A return visit is a new visit. Before an interaction, preserve a pencil sketch of the last walking view and the route to that point.

Keep the larger portraits in the outer corners. Text wraps above and beside their fixed spaces. Earlier pages must retain their own artwork and text when the live scene changes.

## Record

Append journey leaves in the same chronological stream as dialogue. Each leaf has a stable source marker, place and chapter, visit identity, route points, facing, and a saved sketch. Record arrival, interaction boundaries and departures. Sample actual walking positions rather than inventing travel prose. Idle frames do not create entries. Preserve visits that contain no interaction.

An active visit accumulates movement. Committed leaves never change. Use the recovered floor plan to place the route, and derive the pencil view from the actual room render. Keep the source view before a counter or door replaces it. If a room render is unavailable, retain the floor plan and route.

The builder will use one leaf per recorded arrival or interaction/departure boundary. Several leaves can belong to the same visit. This keeps earlier leaves immutable while later movement extends the record.

Dialogue keeps portrait references at passage boundaries. Historical leaves use those references rather than the current cast. Live animation can continue on the current page. Repeated dialogue after a new journey boundary belongs to that part of the journey.

## Reading and storage

Journey leaves participate in the existing page turns and reading cursor. They have source ranges so save bookmarks remain unambiguous. Review includes both dialogue and movement. Preserve the book across walking saves, interaction saves and native chapter saves. Older saves without journey data remain readable.

Incremental saves append new journey records and route points. They must not copy every earlier image on each walking update. Restore must not record replayed inputs a second time. Page geometry and text-size changes may repaginate for the display. Scene changes do not.

## Verification

Check chronological interleaving, repeated visits, stationary movement, interaction capture, passage deduplication boundaries, immutable earlier pixels, historical portraits, backward-compatible saves, incremental save round trips, and resume without duplicate entries. Render a book spread with a route and pencil view. Run the existing dialogue, page-turn and save suites, then build the iOS target.
