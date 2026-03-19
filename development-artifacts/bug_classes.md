# Bug Classes

## Card with spurious keywords field
Cards that grant keywords to other cards (via `grant_keyword` triggered abilities or by summoning creatures with keywords) should not have those keywords in their own `keywords` array, as this causes the keyword to display as a bold header on the card. Applies to both support cards and creatures.
Example: Elixir of Deflection, Wardcrafter, Baron of Tear, General Tullius
