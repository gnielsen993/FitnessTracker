# CLAUDE.md
## Ecosystem Agent Rules (DesignKit + HabitTracker + FitnessTracker + PantryPlanner)

Claude Code reads this file at the start of every session. Follow it as the project constitution. :contentReference[oaicite:3]{index=3}

---

## 0) What you are building
A set of local-first SwiftUI apps that feel like one premium ecosystem, powered by a shared DesignKit Swift Package.

Projects:
- DesignKit (shared design system package)
- HabitTracker (binary habits + optional weekly goals + widgets)
- FitnessTracker (split logging + muscle coverage + visuals)
- PantryPlanner (pantry forecasting + meal planner + cost awareness)

---

## 1) Absolute Constraints (Do Not Violate)
### Stack
- Swift + SwiftUI
- SwiftData for persistence (default)
- MVVM (lightweight)
- Offline-only in v1 (no cloud/backends)

### Data safety
- Implement Export/Import JSON in every app (schemaVersion + replace import at minimum).
- Never break existing local data without a migration path or export/import workaround.
- Avoid bundle ID / App Group ID changes.

### Design
- No hard-coded colors in UI.
- All UI uses DesignKit semantic tokens.
- Theme identity: Balanced Luxury
  - Light: warm cream background
  - Dark: charcoal background
  - Accents constrained to: forest, navy, maroon/oxblood, walnut, stone
- “Personality” is achieved by presets and layout emphasis, not random styling.

---

## 2) DesignKit: How it should work
### What goes into DesignKit
- Theme tokens: colors, typography, spacing, radii, motion
- ThemeManager: mode (system/light/dark) + preset (Forest/Navy/Maroon/Walnut/Stone)
- Components: DKCard, DKButton, DKProgressRing, DKBadge, DKSectionHeader
- Charts: DKChartStyle helper for Swift Charts

### What does NOT go into DesignKit
- App domain models (Habit, WorkoutSession, PantryItem, etc.)
- App business logic engines (streaks, coverage, forecasting)
- Domain-specific icon libraries (exercise drawings, food illustrations)

### Future (explicitly allowed but not required now)
- Design Dashboard hooks:
  - Category color/icon overrides (constrained palette)
  - Export/import theme JSON
- Implement only when requested.

---

## 3) Shared App Structure (Keep Consistent)
Apps must use:
- Models/
- Services/
- Features/
- UIComponents/ (app-specific only)
- Widgets/ (if present)
- Resources/
- Docs/

DesignKit uses:
- Theme/
- Typography/
- Layout/
- Motion/
- Components/
- Charts/
- Storage/
- Utilities/

---

## 4) Rules for AI-assisted changes (avoid ecosystem drift)
- Reuse existing patterns in the repo. Do not invent new architectures.
- Prefer the smallest change that satisfies the requirement.
- Extract to DesignKit ONLY when repetition is proven (used in 2+ apps).
- Engines should be pure/testable modules with deterministic behavior:
  - Habit: StreakEngine, WeeklyGoalEngine, StatsEngine
  - Fitness: CoverageEngine, ProgressionEngine, StatsEngine
  - Pantry: ForecastEngine, MealAggregationEngine, CostEngine

---

## 5) Widgets guidance (when present)
- Use WidgetKit + App Intents for quick toggles where possible.
- Keep widget data minimal (snapshot/cache) and refresh timelines intentionally.
- If sharing theme across widgets/apps is needed later, use stable App Group storage.

---

## 6) Testing expectations
- Add unit tests for core engines (streak/coverage/forecast/cost math).
- Verify export/import round-trip where feasible.
- For UI: keep tests minimal unless explicitly requested.

---

## 7) Definition of done (for any task)
A task is done when:
- code compiles
- behavior is verified (explain what was run / checked)
- structure + token rules are followed
- no new drift introduced

---

## 8) When unsure
Choose:
- vertical slice > architecture
- clarity > abstraction
- TODO hook > overbuilding


