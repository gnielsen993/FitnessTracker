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

### Notes
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
