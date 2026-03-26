# FitTracker+ Change Log (Paper Trail)

This log is a human-readable paper trail of product-facing changes.

## 2026-03-23

### Completed
- **#27 Rest timer reliability hardening**
  - Removed auto-stop on Train screen disappear.
  - Moved timer onto common runloop mode to prevent freezes during UI interactions.
  - Result: timer continues across navigation/input unless manually stopped, force-closed, or reset by new set.

- **#24 Done behavior improvement**
  - Marking an exercise as Done now auto-returns to workout list.
  - Undo keeps user on detail screen.

- **#29 Cardio entry-first MVP**
  - Cardio is now treated as entry-first UX (not set wording).
  - Added optional cardio fields: **distance** and **incline %**.
  - Cardio completion rule set to: at least one non-warmup entry.
  - Updated cardio labels and editor flows to use entry language.


- **#21 Active workout return banner**
  - Added global bottom "active workout" bar on non-Train tabs.
  - Bar shows current workout, last logged exercise, and live rest timer context.
  - One tap jumps user back into Train workflow quickly.


- **#20 Keyboard close UX**
  - Tapping outside numeric input now dismisses keyboard in exercise detail flow.
  - Added explicit keyboard "Done" action for quick dismissal.


- **#22 Autofill exercise inputs from last set**
  - Re-entering an exercise now prefills from the latest in-progress set.
  - If no in-progress set exists, fields prefill from most recent historical set.
  - Prevents default fallback to 45 x 10 unless no prior data exists.


- **#19 Wording cleanup pass**
  - Removed redundant top screen titles that duplicated tab names.
  - Updated Home hero copy from "Performance Lab" / "Train with data, not vibes." to clearer plain-language wording.
  - Performed quick copy cleanup sweep on top-level tab surfaces.


- **#9 Routine-defined target sets UX**
  - Target sets are now configured in routine builder per exercise (default remains 3).
  - Replaced generic Stepper with cleaner `- [value] +` control where center value is editable.
  - Removed target-set +/- controls from in-workout exercise screen to reduce clutter.


- **#23 Home quick-start + routine ordering**
  - Added Home "Start Workout" card with suggested next routine and one-tap start.
  - Added "Choose Different" path to jump into Train for manual choice.
  - Added routine ordering controls in Manage Routines so suggestion follows user-defined sequence.


- **#18 Rest-complete notification**
  - Added visible "Rest complete" bottom banner when countdown reaches zero.
  - Banner auto-dismisses after ~2 seconds and complements haptic feedback.


- **#26 Logger hub replaces quick add**
  - Converted "Quick Add" into a full-width primary set logger hub.
  - Added logger mode toggles for Weight / Pin / Bodyweight.
  - Bodyweight and pin sets now save with explicit mode metadata and render correctly in logs.
  - Kept pull-up editor flow for edits only.


- **#15/#25/#30 Workout flow quick-win bundle**
  - Made exercise rows fully tappable across the full row hit area.
  - Moved exercises section above notes/coverage to prioritize logging flow.
  - Added workout-complete feedback: quick "Workout logged" banner plus full routine-complete sheet when all planned work is done.


- **#17 Full-width logger sweep**
  - Converted set logger modes (weight/pin/bodyweight) to full-width input layouts.
  - Standardized logger controls as a cleaner vertically stacked entry hub.


- **#16 Dynamic Island timer priority with music**
  - Removed compact trailing branding icon to avoid timer being displaced when other Live Activities (music) are present.
  - Minimal island now prioritizes timer/status indicator instead of app icon.


- **Timer utility + reliability pass**
  - Added optional timed-set metric (seconds) for Weight/Pin/Bodyweight logger modes (e.g., planks without fake reps).
  - Logger/editor now support Reps vs Time per entry and preserve correct formatting in history.
  - Added app-start cleanup to end stale Live Activities when no workout is active.
  - Enhanced Dynamic Island completion indicator prominence in compact/minimal states.


- **#28 Setup variant tracking (single exercise source of truth)**
  - Removed equipment-specific noise from routine/exercise creation displays.
  - Added per-entry "Setup / Variant" field in logger and editor (e.g., Cable Station 1, Plate Loaded).
  - Preserved one canonical exercise name while allowing separate progression contexts.


- **Timer polish: analog-style timed set UX**
  - Timed-set input now accepts and displays `MM:SS.CC` style formatting (e.g., `00:45.00`).
  - Added inline countdown controls (Start/Pause/Reset) in logger hub when Time metric is selected.
  - Timed entries persist correctly in quick logger + editor save paths.

### Notes
- `4c0f6e2` (row tap, exercises-first layout, completion feedback)
- Commit refs:
  - `eb31c58` (timer navigation fix)
  - `4f24565` (timer runloop hardening)
  - `41b261f` (done auto-return)
  - `6ab87ad` (cardio entry-first + distance/incline)
  - `5a13782` (global active workout return banner)
  - `2362bfc` (keyboard dismissal improvements)
  - `3731715` (autofill from latest set history)
  - `b53de7d` (top-level wording and title simplification)
  - `0063281` (routine-managed target sets + cleaner control)
  - `597e45d` (home quick-start suggestions + routine ordering)
  - `eedbfae` (rest-complete banner notification)
