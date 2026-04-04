# UI Style Guide

All UI screens use the shared `UITheme` utility at `src/ui/ui_theme.gd`. Screens are built programmatically (no .tscn files). This document defines the visual language so new screens stay consistent.

## Implementation

`UITheme` is loaded via preload in each file that uses it:

```gdscript
const UITheme = preload("res://src/ui/ui_theme.gd")
```

It is NOT registered as a global class_name (Godot headless mode has issues with .uid generation).

## Color Palette

| Token | Value | Usage |
|---|---|---|
| `BG_COLOR` | `(0.08, 0.08, 0.12)` | Full-screen background on every screen |
| `GOLD` | `(0.85, 0.72, 0.4)` | Titles, hover borders, selected state borders |
| `GOLD_DIM` | `(0.72, 0.58, 0.3, 0.7)` | Separators, normal borders, secondary accents, quantity labels |
| `GOLD_BRIGHT` | `(1.0, 0.9, 0.6)` | Pressed state borders and text |
| `TEXT_LIGHT` | `(0.9, 0.85, 0.7)` | Primary button/body text (warm cream) |
| `TEXT_MUTED` | `(0.6, 0.55, 0.45, 0.8)` | Subdued buttons (Back, Quit), empty state labels |
| `TEXT_SECTION` | `(0.72, 0.58, 0.3, 0.8)` | Section headers, subtitles |
| `BTN_BG` | `(0.12, 0.11, 0.15, 0.9)` | Button normal background |
| `BTN_BG_HOVER` | `(0.18, 0.16, 0.2, 0.95)` | Button hover background |
| `BTN_BG_PRESSED` | `(0.22, 0.19, 0.12)` | Button pressed background (warm shift) |
| `PANEL_BG` | `(0.1, 0.1, 0.14, 0.98)` | Panel/card backgrounds |
| `PANEL_BORDER` | `(0.72, 0.58, 0.3, 0.5)` | Panel borders (semi-transparent gold) |

## Typography Scale

| Element | Font Size | Color | Helper |
|---|---|---|---|
| Main menu title | 56px | GOLD | `style_title(label, 56)` |
| Screen title | 40px | GOLD | `style_title(label, 40)` |
| Sub-panel title | 24-28px | GOLD | `style_title(label, 28)` |
| Subtitle / spaced text | 30px | TEXT_SECTION | `style_section_label(label, 30)` |
| Section header | 20px | TEXT_SECTION | `style_section_label(label, 20)` |
| Primary button | 22-28px | TEXT_LIGHT | `style_button(btn, 22)` |
| Secondary/small button | 18-20px | TEXT_LIGHT | `style_button(btn, 18)` |
| Subdued button (Back/Quit) | 22px | TEXT_MUTED | `style_button(btn, 22, true)` |
| Body text | 18-20px | TEXT_LIGHT | manual override |
| Empty state | 18-20px | TEXT_MUTED | manual override |

## Component Patterns

### Screen Background
Every screen starts with `UITheme.add_background(self)`.

### Screen Layout
Full-screen screens use a consistent margin container:
```gdscript
var margin := MarginContainer.new()
margin.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
margin.add_theme_constant_override("margin_left", 80)
margin.add_theme_constant_override("margin_right", 80)
margin.add_theme_constant_override("margin_top", 50)
margin.add_theme_constant_override("margin_bottom", 50)
```

### Header Row
Screens accessible from the main menu use a header with Back button + title:
```gdscript
var header := HBoxContainer.new()
header.add_theme_constant_override("separation", 20)

var back_button := Button.new()
back_button.text = "Back"
back_button.custom_minimum_size = Vector2(120, 56)
UITheme.style_button(back_button, 22, true)  # subdued

var title := Label.new()
title.text = "Screen Title"
title.size_flags_horizontal = SIZE_EXPAND_FILL
UITheme.style_title(title, 40)
title.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
```

Followed by a full-width separator: `UITheme.make_separator(0.0)` (0 width = fills parent).

### Buttons
- **Standard**: `UITheme.style_button(btn, font_size)` -- gold borders, cream text
- **Subdued** (Back, Quit, Cancel): `UITheme.style_button(btn, font_size, true)` -- muted text
- **Accent** (Delete, special actions): `UITheme.style_button_accent(btn, accent_color, font_size)` -- custom border color (e.g. red for delete)
- **Selected state**: `UITheme.style_button_selected(btn)` -- gold border, warm background
- Minimum heights: main menu 72px, screen actions 56-64px, list items 52px, dialog buttons 48px

### Panels / Cards
`UITheme.style_panel(panel)` gives dark bg + gold border + rounded corners. Pass a custom `border_color` for variants (e.g. red-tinted for delete confirmations).

### Separators
`UITheme.make_separator(width)` creates a 2px gold line. Use `480.0` for centered decorative lines, `0.0` for full-width dividers.

### Dialogs / Overlays
- Semi-transparent black backdrop: `Color(0, 0, 0, 0.6)`
- Centered panel with `UITheme.style_panel()`
- Title uses `style_title()` at 22-28px
- Cancel button is subdued, confirm button is standard or accent

## Attribute Icons
Located at `res://assets/images/attributes/{id}-small.png`. Use `ResourceLoader.load()` with `TextureRect` at 36x36 for inline display. Available: strength, intelligence, willpower, agility, endurance, neutral.

Note: the full-size willpower icon has a typo in filename (`wilpower.png`) but the small version is correct (`willpower-small.png`).

## Design Principles
- Dark background everywhere -- no bare Godot grey
- Gold is the accent color for everything interactive
- Warm cream text, never pure white (except on colored badges)
- Buttons always have visible borders and 3 states (normal, hover, pressed)
- Generous sizing -- minimum 52px height for clickable elements, 20px+ font sizes
- Consistent spacing: 80px horizontal margins, 50px vertical margins on full screens
