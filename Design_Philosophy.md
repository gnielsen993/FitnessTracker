# Design Philosophy — Balanced Luxury

## Identity
A quiet, premium “modern heritage” aesthetic:
- warm cream light mode
- deep charcoal dark mode
- accents: forest green, navy, maroon, walnut browns
- restrained, calm, intentional

## Rules
1. No hard-coded colors in UI.
2. Only use semantic tokens from DesignKit (Theme).
3. Charts must use the theme’s chart palette (no rainbow).
4. Spacing, corner radius, and motion use shared tokens.
5. Apps can have personality via preset defaults, not random styling.

## Theme Behavior
- Default: follows System light/dark mode
- In-app picker allows override: System / Light / Dark
- Presets: Forest / Navy / Maroon / Walnut / Stone

## Cream Requirement
Light mode background should always be a warm cream tone (not pure white).
Cards/surfaces use slightly darker warm neutrals for depth.

## Future: Design Dashboard (Planned)
A future settings screen may allow:
- category color overrides
- icon overrides (SF Symbols)
- background variants
- export/import of theme JSON

This must preserve the “luxury” constraint (no neon / no high-saturation chaos).

