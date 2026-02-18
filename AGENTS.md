# AGENTS.md
## Ecosystem Agent Rules (DesignKit + HabitTracker + FitnessTracker + PantryPlanner)

Codex reads this file before doing any work. Follow these rules exactly. :contentReference[oaicite:2]{index=2}

---

## 0) Goal
Build a cohesive, local-first ecosystem of SwiftUI apps with a shared luxury design language and minimal architectural drift.

Projects in the ecosystem:
- DesignKit (shared Swift Package)
- HabitTracker (local-first habit app)
- FitnessTracker (local-first workout app)
- PantryPlanner (smart pantry + meal planner app)

---

## 1) Non-Negotiables (Hard Constraints)
### Tech & Architecture
- Language: Swift
- UI: SwiftUI
- Persistence: SwiftData (default)
- Pattern: lightweight MVVM (no heavy frameworks unless explicitly asked)
- Offline-first, no backend/cloud in v1 apps
- All apps must support **Export/Import** backup (JSON, versioned)

### Design System
- No hard-coded colors in app UI.
- All styling uses DesignKit semantic tokens.
- Use “Balanced Luxury” palette:
  - Light mode: warm cream background
  - Dark mode: charcoal (not pure black)
  - Accents: forest green, navy, maroon/oxblood, walnut browns, stone neutrals
- Each app may choose a default preset, but must stay within the shared token system.

### Widgets (if requested by task)
- Use WidgetKit + App Intents for quick actions (where available).
- Widgets should use shared theme snapshot logic when applicable.
- Widgets are not real-time; design for timeline refresh constraints.

---

## 2) Repository & Module Boundaries
### DesignKit (shared)
DesignKit contains ONLY:
- semantic design tokens (colors, typography, spacing, radii, motion)
- reusable UI components (Card, Button, ProgressRing, Badge, SectionHeader)
- consistent chart styling helpers (Swift Charts)
- theme resolution (system/light/dark + preset)
- optional future hooks for category/icon overrides (do not implement early unless asked)

DesignKit contains NO:
- app business logic
- app models
- persistence models for app data
- domain-specific illustrations/ingredient/exercise libraries

### Apps (Habit/Fitness/Pantry)
Apps contain:
- models (SwiftData)
- services/engines (stats, coverage, forecasting, export/import)
- feature modules (Today/Calendar/Progress etc.)
- app-specific assets/content
Apps must NOT duplicate DesignKit styling logic.

---

## 3) File/Folder Structure (Use Consistently)
In each app:
- Models/
- Services/
- Features/
- UIComponents/   (app-specific only; shared goes to DesignKit)
- Widgets/        (if present)
- Resources/
- Docs/

In DesignKit package:
- Theme/
- Typography/
- Layout/
- Motion/
- Components/
- Charts/
- Storage/
- Utilities/

---

## 4) Coding Standards
- Prefer clarity over abstraction.
- Avoid premature frameworks or patterns (no TCA/Redux unless explicitly requested).
- Keep view models small and testable.
- Use `final` classes where appropriate.
- Prefer pure functions for engines (StatsEngine, CoverageEngine, ForecastEngine).
- Add unit tests for “engine” logic (streaks, coverage, forecasting, export/import).

---

## 5) Data Safety & Updates
- Never change bundle identifiers or app group IDs once daily use begins.
- Schema changes must be additive when possible.
- Always keep export/import working; use schemaVersion.
- Never delete user data automatically.

---

## 6) Workflow for Any Task (Explore → Plan → Implement → Verify)
1) Explore: locate relevant files, note existing patterns.
2) Plan: propose minimal change list + touched files.
3) Implement: small diffs, follow structure + tokens.
4) Verify: run tests/build; provide proof (what ran, what changed).

---

## 7) If Uncertain
If ambiguity exists, prefer:
- simplest approach that fits constraints
- incremental change (vertical slice)
- keep future hooks as TODOs rather than building systems now

---

## 8) Commands (fill in per repo if needed)
- Build: (Xcode build)
- Tests: (Xcode test)
- Lint/format: (optional; keep consistent if introduced)


