# Bug Classes

## Support card with spurious keywords field
Support cards that grant keywords to other cards via `grant_keyword` triggered abilities should not have those keywords in their own `keywords` array, as this causes the keyword to display as a bold header on the card.
Example: Elixir of Deflection, Skirmisher's Elixir, Volendrung, Elixir of the Defender
