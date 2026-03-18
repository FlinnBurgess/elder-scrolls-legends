# Deck Builder UI Overhaul

## Problem Statement

The current deck builder UI is functional but not visually appealing. Cards are displayed as text rows with `+`/`-` buttons rather than visual card representations. There is no persistent deck management — decks can only be imported/exported via JSON. The UI doesn't make good use of available screen space, and features like the magicka curve are presented as a text string rather than an intuitive visual.

## Solution

Overhaul the deck builder into a multi-screen experience with persistent deck management. The entry point is a deck list screen showing all user-created decks with the ability to create new decks or edit/delete existing ones. The deck editor features a visual card grid browser on the left using full card display components, and a compact deck panel on the right with a graphical magicka curve bar chart. Decks are persisted to `user://` storage automatically when the user hits "Done."

## User Stories

1. As a player, I want to see a list of my saved decks when I open the deck builder, so that I can quickly find and edit the deck I want to work on.
2. As a player, I want to create a new deck by entering a name and selecting 1-3 attributes, so that I can start building a deck with the correct card pool.
3. As a player, I want to delete a deck from the list with a confirmation dialog, so that I don't accidentally lose a deck.
4. As a player, I want to see cards in the browser displayed as full visual card representations in a grid, so that I can quickly identify cards by their artwork, stats, and layout.
5. As a player, I want the card grid to scale its 3 columns to fill available space, so that cards are as large and readable as possible.
6. As a player, I want to single-click a card in the grid to add one copy to my deck, so that building a deck is fast and intuitive.
7. As a player, I want to see a quantity badge on grid cards showing how many copies are already in my deck, so that I can track my selections at a glance.
8. As a player, I want cards at their copy limit to appear greyed out, so that I can immediately see which cards I can no longer add.
9. As a player, I want to filter cards by attribute using toggle chips, so that I can quickly narrow the card pool to specific colours.
10. As a player, I want to filter cards by magicka cost using toggle chips (0-7+), so that I can find cards at specific points on my curve.
11. As a player, I want to filter cards by class, type, and keyword using dropdowns, so that I can narrow the card pool by more specific criteria.
12. As a player, I want to search cards by name using a text input, so that I can quickly find a specific card I'm looking for.
13. As a player, I want to see my deck as a compact list sorted by card cost, with each row showing cost badge, card name, quantity, and a minus button, so that I can review and manage my deck efficiently.
14. As a player, I want to click the minus button on a deck row to remove one copy of that card, so that I can adjust my deck composition.
15. As a player, I want to see a blue bar chart magicka curve below my deck list, so that I can assess my deck's cost distribution at a glance.
16. As a player, I want to see the card count displayed alongside the magicka curve, coloured red when the deck is invalid and white when valid, so that I know whether my deck meets size requirements.
17. As a player, I want to click the deck name and attribute icons at the top of the editor to open an edit modal, so that I can rename my deck or change its attributes.
18. As a player, I want to be warned and asked for confirmation when removing an attribute that would cause cards to be removed from my deck, so that I don't accidentally lose deck contents.
19. As a player, I want a "Done" button that saves my deck and returns to the deck list, so that I can persist my work.
20. As a player, I want a visually distinct "Cancel" button that discards changes and returns to the deck list, so that I can back out without saving.
21. As a player, I want neutral cards to always appear in the browser regardless of my deck's attribute selection, so that I can always access attribute-neutral cards.
22. As a player, I want the card grid to not show hover effects on cards, so that the deckbuilder view stays clean and focused.
23. As a player, I want decks to be saved to persistent storage that survives between game sessions, so that my decks are not lost.
24. As a player, I want mono and dual-attribute decks to allow 50-100 cards, and triple-attribute decks to allow 75-100 cards, so that deck construction follows the game's rules.
25. As a player, I want the attribute selection to enforce a minimum of 1 and maximum of 3 attributes, so that I can't create an invalid deck identity.

## Implementation Decisions

### Modules to Build/Modify

- **DeckPersistence** (new): Handles saving, loading, listing, and deleting user decks in `user://decks/`. Pure data module with a simple interface (`save_deck`, `load_deck`, `list_decks`, `delete_deck`). JSON-based serialization matching the existing deck definition format (`attribute_ids` + `cards` array with `card_id`/`quantity` entries). Deck name is stored within the definition.

- **DeckListScreen** (new): Entry point screen displaying saved deck names in a list. Provides "Create New Deck" button and per-deck delete buttons with confirmation dialogs. Emits signals for navigation (create, edit).

- **DeckCreationModal** (new): Popup dialog with a name text field and 5 attribute toggle buttons (1-3 selectable; remaining disabled once 3 are selected). Reused as the edit modal when clicking the deck header in the editor. When used for editing, removing an attribute that would invalidate existing cards triggers a confirmation dialog explaining which cards will be removed.

- **DeckEditorScreen** (replaces existing `DeckbuilderScreen`): Two-column layout. Left column: filter bar (attribute and cost toggle chips, class/type/keyword dropdowns, name search) above a 3-column scrollable grid of `CardDisplayComponent` instances in `PRESENTATION_FULL` mode. Right column: clickable deck header (name + attribute icons) → scrollable compact card list sorted by cost (cost badge, name, quantity, minus button) → magicka curve bar chart with card count → Done and Cancel buttons. No import/export panel. No card inspector panel.

- **MagickaCurveChart** (new): Self-contained widget accepting a deck definition. Renders a vertical bar chart with 8 cost buckets (0-7+). Bars are blue accent colour with count labels. Includes a card count label that is red when the deck is invalid, white otherwise.

- **CardDisplayComponent** (existing, modify): Add a flag to disable hover effects for deckbuilder use. Add support for a quantity badge overlay (small indicator showing copies in deck, e.g., "2/3"). Add a greyed-out visual state for cards at their copy limit.

### Architecture Decisions

- All UI remains fully programmatic (no `.tscn` scene files) — this is an AI-driven codebase and programmatic construction is easier for AI agents to maintain.
- Existing `DeckValidator`, `DeckRulesRegistry`, and `CardCatalog` modules are unchanged — the new UI calls into them as-is.
- Screen navigation (list → editor, editor → list) should use the simplest approach for AI maintainability.
- Deck definitions use the existing JSON format: `{ "name": "...", "attribute_ids": [...], "cards": [{ "card_id": "...", "quantity": N }] }`.

## Testing Decisions

Good tests verify external behavior through the module's public interface without coupling to implementation details. They should be resilient to refactoring — if the internal structure changes but the behavior stays the same, tests should still pass.

### Modules to Test

- **DeckPersistence**: Test the full save/load round-trip (save a deck, load it back, verify equality). Test `list_decks` returns correct names. Test `delete_deck` removes the deck and it no longer appears in the list. Test loading a non-existent deck returns an appropriate result. These tests exercise file I/O against `user://` storage.

- **MagickaCurveChart**: Test the bucket calculation logic — given a deck definition with known card costs, verify the computed bucket counts are correct. Test edge cases: empty deck, all cards at 7+ cost, single card. The bar rendering itself is visual and doesn't need automated testing; the data transformation does.

### Prior Art

Existing test runners in `tests/` follow a pattern of extending a base runner script, with test methods prefixed with `test_`. See `tests/deck_validation_runner.gd` and `tests/deckbuilder_ui_runner.gd` for examples of deck-related tests.

## Out of Scope

- Import/export functionality (removed from this version of the UI)
- Card inspector panel (the full card grid display replaces this need)
- Drag-and-drop for adding/removing cards
- Deck sharing or multiplayer deck features
- Card art assets or card data changes
- Undo/redo for deck edits
- Deck sorting/filtering on the deck list screen
- Auto-save or save-on-exit behaviour (explicit "Done" button only)

## Further Notes

- The deck name field is added to the existing deck definition format (currently definitions don't have a `name` field at the top level, though example JSON files in `data/decks/` do include one).
- The existing `DeckbuilderScreen` (860 lines) will be replaced, not incrementally modified — the layout and interaction model are fundamentally different.
- `CardDisplayComponent` is 1036 lines and handles complex rendering including shaders, particles, and multiple presentation modes. Modifications should be minimal and additive (a disable-hover flag, a quantity badge, a greyed-out modulate).
