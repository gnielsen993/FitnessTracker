# FitTracker+ TestFlight Tester Manual

## Build Under Test
- App: FitTracker+
- Track latest internal build in TestFlight (highest build number)

## Test Focus Areas
1. **Workout start/resume flow**
   - Home "Start Workout" suggestion
   - "Choose Different" to Train
   - Active workout bottom resume bar behavior

2. **Set Logger Hub**
   - Modes: Weight / Pin / Bodyweight
   - Full-width logger inputs
   - Edit flow still works from row tap

3. **Cardio Entry Flow**
   - Duration, pace/speed, zone, distance, incline
   - Cardio completion after at least one entry

4. **Timer Reliability**
   - Timer persists across navigation/input
   - Rest complete banner appears and dismisses
   - Dynamic Island timer priority while music is playing

5. **Autofill & Logging**
   - Re-enter exercise -> values prefill from latest set
   - No fallback to 45x10 when history exists

## Pass/Fail Checklist
- [ ] Start suggested workout from Home
- [ ] Log weight set successfully
- [ ] Log pin set successfully
- [ ] Log bodyweight set successfully
- [ ] Log cardio entry with distance/incline
- [ ] Timer continues when switching screens
- [ ] Rest-complete banner appears
- [ ] Dynamic Island keeps timer visible with music
- [ ] Reopening exercise prefills last values
- [ ] End workout shows success feedback

## Reporting Template
- Device:
- iOS version:
- Build version:
- Scenario tested:
- Expected:
- Actual:
- Severity: blocker / major / minor
- Screenshot/video:
