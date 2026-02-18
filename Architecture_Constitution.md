# ARCHITECTURE_CONSTITUTION.md
## Non-Negotiable Rules for the Ecosystem

---

# 1) Core Technology Decisions

- Language: Swift
- UI Framework: SwiftUI
- Persistence: SwiftData (unless explicitly overridden)
- Architecture Pattern: MVVM (lightweight)
- No backend unless explicitly planned
- No cloud dependencies in v1 apps

AI must not suggest alternatives unless asked.

---

# 2) Design System

- All UI colors must come from DesignKit tokens.
- No hard-coded color values in app UI.
- No duplicate spacing/radius values.
- Charts must use DesignKit chart style.

AI must conform to DesignKit usage.

---

# 3) Project Structure Pattern

Each app must use:

- Models/
- Features/
- Services/
- UIComponents/
- Settings/
- Resources/

AI must follow this structure when generating examples.

---

# 4) State Management

- Use ObservableObject / @StateObject / @EnvironmentObject
- Avoid introducing Redux, TCA, or other heavy frameworks unless explicitly requested.

---

# 5) Data Safety

- All apps must implement export/import.
- No destructive schema changes without migration.
- No identifier changes once app is live.

---

# 6) Package Strategy

- Shared UI logic lives in DesignKit (Swift Package).
- App-specific logic stays inside the app.

AI must not suggest copying UI logic between apps manually.

---

# 7) Simplicity Rule

When multiple approaches exist:
Choose the simplest one that satisfies the requirement.

AI must prefer clarity over abstraction.

---

# 8) Refactor Discipline

No premature abstraction.
Extract only when repetition is proven.

---

# 9) Naming Consistency

Use consistent naming:
- ThemeManager
- StatsEngine
- CoverageEngine
- WeeklyGoalEngine

Avoid inconsistent suffix patterns.

---

# 10) Evolution Policy

Architect for extension, not prediction.
Do not build unused layers "just in case".

