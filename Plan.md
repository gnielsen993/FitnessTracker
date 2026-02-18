# Local-First Fitness Tracker (Swift)
## Version 1 Spec — Split-Aware + Muscle Coverage Engine

---

# 0) Core Philosophy

A local-only, privacy-first strength training tracker that:

- Works fully offline
- Uses on-device persistence (SwiftData)
- Tracks muscle region coverage per workout
- Supports customizable split types (Push, Pull, Full Body, etc.)
- Provides visual progress: calendars, charts, graphs
- Designed to look impressive on GitHub

No cloud. No accounts. No subscriptions.

---

# 1) High-Level User Flow

## Train Tab (Main Entry)

When user taps “Start Workout”:

1. Select Workout Type:
   - Push
   - Pull
   - Legs
   - Upper
   - Lower
   - Full Body
   - Custom

These are default presets, but user can create/edit custom splits.

2. Start Session

3. During workout:
   - Add exercises
   - Log sets
   - Live coverage scoreboard updates

---

# 2) Split System Architecture

## WorkoutType (enum or entity)
- id
- name
- includedMuscleGroups: [MuscleGroup]

Example:
Push:
- Chest
- Triceps
- Shoulders

Pull:
- Back
- Biceps
- Rear Delts

Full Body:
- All major groups

User can:
- Edit which muscle groups belong to a split
- Create new splits

This avoids hardcoding Chest/Triceps/Shoulders permanently.

---

# 3) Muscle Architecture System

## MuscleGroup
- id
- name (Chest, Triceps, etc.)

## MuscleRegion
- id
- groupId
- name (Upper Chest, Long Head, etc.)

### Default Region Taxonomy (Balanced + Practical)

Chest:
- Upper
- Mid
- Lower

Triceps:
- Long
- Lateral
- Medial

Shoulders:
- Anterior
- Lateral
- Posterior

Biceps:
- Long
- Short
- Brachialis

Back:
- Lats
- Upper Back
- Lower Back

Legs:
- Quads
- Hamstrings
- Glutes
- Calves

Core:
- Upper Abs
- Lower Abs
- Obliques

This is extensible.

---

# 4) Exercise Internal Database (Seeded)

On first launch:
- Load bundled JSON of exercises
- Insert into local DB
- No network calls

Each Exercise includes:

- id
- name
- category
- equipment
- ExerciseMuscleMap[]

## ExerciseMuscleMap
- exerciseId
- muscleRegionId
- role (primary/secondary)

We do NOT weight by volume for v1.

---

# 5) Coverage Engine (Binary: Touched / Not Touched)

## Philosophy
A region is considered “touched” if:
- At least one working set of an exercise mapped to that region is logged.

No thresholds.
No stimulus math.
Clear and simple.

---

## CoverageEngine

Input:
- WorkoutSession
- WorkoutType

Output:
- CoverageReport

CoverageReport:
- For each MuscleGroup in WorkoutType:
  - totalRegions
  - touchedRegions
  - list of touched/missed regions

Example Output (Push):

Push Coverage
Chest: 2/3
Triceps: 1/3
Shoulders: 0/3

Chest:
- Upper ✅
- Mid ✅
- Lower ❌

---

# 6) Live Session UI

## Active Workout Screen

Top Card:

---------------------------------
Push Coverage
Chest: 2/3
Triceps: 1/3
Shoulders: 0/3
---------------------------------

Tap card →
Detail sheet with region checklist (auto-computed)

As sets are logged:
Coverage updates instantly.

---

# 7) Visual Progress System

This is where it becomes impressive.

## 7.1 Calendar View (History Tab)

Monthly calendar:

- Days with workouts = colored dots
- Tap day → session summary
- Color intensity = total volume

Optional:
- Filter by split type (show only Push days)

---

## 7.2 Exercise Detail Charts

Using Swift Charts:

For each exercise:

1. Volume Over Time (Line Graph)
   - X: Date
   - Y: Total volume

2. Estimated 1RM Trend (Line Graph)
   - X: Date
   - Y: 1RM

3. Reps at Weight (Scatter plot)
   - See progression visually

---

## 7.3 Muscle Coverage Trends (Unique Feature)

For each split type:

Show heat-style visualization:

Example:
Push Split Heat Map (last 8 sessions)

Chest Upper: 🟩🟩🟩🟨⬜⬜🟩🟩
Chest Mid: 🟩🟩🟩🟩🟩🟨🟩🟩
Chest Lower: ⬜⬜🟨⬜⬜⬜⬜⬜

This makes imbalance obvious.

---

## 7.4 Dashboard (Progress Tab)

Cards:

- Weekly Volume Graph (bar chart)
- Workout Frequency (line graph)
- Split Distribution (pie chart)
- Muscle Coverage % (stacked bar per group)

---

# 8) Data Model Summary

Entities:

Exercise
MuscleGroup
MuscleRegion
ExerciseMuscleMap
WorkoutType
WorkoutTemplate
WorkoutSession
SessionExercise
SetEntry

All persisted via SwiftData.

---

# 9) Export / Import

Settings:
- Export JSON
- Import JSON
- Versioned schema

JSON includes:
- exercises
- sessions
- templates
- splits

No cloud sync.

---

# 10) Milestones (Build Order)

## Phase 1 – Core
- Models (SwiftData)
- Split selection
- Exercise library
- Log sets
- Save session

## Phase 2 – Coverage Engine
- MuscleRegion taxonomy
- ExerciseMuscleMap
- Live coverage card

## Phase 3 – History + Calendar
- Monthly calendar
- Session detail

## Phase 4 – Charts
- Exercise detail charts
- Weekly volume graph
- Split distribution graph

## Phase 5 – Polish
- Animations
- Haptics
- UI refinement
- Dark mode optimization

---

# 11) Architecture Structure (GitHub Clean)

Project Structure:

Models/
Services/
  CoverageEngine.swift
  StatsEngine.swift
  ExportImportService.swift
Features/
  Train/
  Templates/
  History/
  Progress/
UIComponents/
Utilities/
Docs/

Unit Tests:
- CoverageEngineTests
- StatsEngineTests
- ExportImportTests

---

# 12) Future Expansion (Curator v2)

After MVP:

CuratorEngine:

Input:
- WorkoutSession
- MissingRegions

Output:
- SuggestedExercises[]

Example:
"You missed Triceps Long Head.
Add 2 sets of Overhead Extension."

This remains fully offline and rule-based.

---

# 13) Target iOS Version

iOS 17+
- SwiftData
- Swift Charts
- Modern SwiftUI navigation

---

# 14) Why This Is Strong for GitHub

- Local-first architecture
- Deterministic coverage engine
- Split-customizable system
- Visual data representation
- Clean MVVM structure
- Testable domain services


## Persistence, Updates, and Data Safety (Local-Only)

This project is designed to be **installed directly from Xcode** (personal use) and may never ship to the App Store. This section documents how local data behaves over time and how to avoid losing it.

### 1) Reality Check: What can cause data loss
Local data is typically preserved across normal rebuilds/updates, but it can be lost if:

- **The app is uninstalled** (iOS deletes the app’s sandbox/container)
- **The Bundle Identifier changes** (iOS treats it as a different app with a fresh container)
- **The storage location changes** (e.g., changing App Group ID or moving the database file path without migration)
- **A breaking database schema change occurs** (no migration path for SwiftData/Core Data)
- **A “reset data” debug action is triggered** (developer-only behavior)

> Important: App signing/provisioning expiring does **not** automatically delete data.
> Data loss typically happens only if you must uninstall to recover.

---

### 2) Updates and rebuilding in the future
Normal development updates (Xcode “Run” installing over the same app with the same Bundle ID) should:

- ✅ keep local database records (SwiftData/Core Data)
- ✅ keep UserDefaults values
- ✅ keep cached files in the app container
- ✅ keep App Group–shared widget cache (if App Group ID stays the same)

As long as you **do not uninstall** and **do not change identifiers**, local data persists.

---

### 3) Manual Backup: Export/Import (recommended for all local-first apps)
Add a simple, versioned **Export / Import** flow to protect against uninstall or migration issues.

#### Export
- Generates a single file (preferably JSON) containing:
  - user-created data (habits/workouts/etc.)
  - user settings (units, pins, schedules, etc.)
  - schemaVersion
  - createdAt timestamp
- Saves to the Files app using a document picker.

#### Import
- Reads the export file
- Validates `schemaVersion`
- Imports with one of two strategies:
  - **Replace**: wipe local store then import everything
  - **Merge**: match by stable IDs and merge updates

> Minimum viable safety: Export + Replace Import.

---

### 4) Schema changes: “Don’t brick your store”
Even personal apps evolve. Prevent accidental wipes:

- Maintain a `schemaVersion` constant in code
- When adding fields:
  - prefer optional fields with sensible defaults
- When renaming/removing fields:
  - plan a migration step or deprecate gradually
- If migration is complex:
  - fall back to export → reinstall → import

---

### 5) Widgets and shared data (if widgets exist)
Widgets are separate extensions, so shared access requires stable identifiers.

#### App Group (recommended)
- Use a single, stable App Group ID, e.g. `group.com.yourname.project`
- Store only a **lightweight widget offer cache** in the App Group:
  - pinned item IDs
  - “today state” snapshot
  - last refresh time
- Keep the main database in the app container unless you explicitly need DB sharing.

#### Refresh behavior
- Widgets are not real-time; they refresh on iOS schedules.
- After in-app changes, request a refresh:
  - `WidgetCenter.shared.reloadTimelines(...)`

---

### 6) Stability checklist (do these and you’re safe)
- [ ] Never change Bundle ID once you start using the app daily
- [ ] Never change App Group ID once widgets ship
- [ ] Implement Export/Import early
- [ ] Add a “Backup Reminder” (optional)
- [ ] Keep schema evolution incremental and versioned
- [ ] Add a Settings “Danger Zone”:
  - Reset local data (explicit user confirmation)
  - Show last backup date/time


