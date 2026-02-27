# Product Roadmap (Manager View)

Audience: Gabe (Product/Manager)
Owner: Jarvis (Implementation)

## Product Direction
FitnessTracker ships as **local-first**, fast, and reliable for individual use, with future optional cloud sync.

## Phase Priorities

### Phase A — Production Stability (Now)
1. Crash resistance + startup reliability ✅
2. Input validation + data integrity ✅
3. Full-width layout and polished default styling ✅
4. Seeded exercise depth for immediate user value ✅

### Phase B — Release Hardening (Next)
1. Device-based accessibility pass (VoiceOver + Dynamic Type)
2. Manual smoke suite on core flows:
   - Start/end workout
   - Add/remove exercises/sets
   - History/progress rendering
   - Export/import backup
3. Error telemetry strategy (lightweight, privacy-aware)

### Phase C — Product Quality Lift
1. Better training ergonomics:
   - Rest timer
   - Simple PR markers
   - Session templates
2. Better analytics:
   - Weekly trends by movement pattern
   - Fatigue/load indicators (basic)
3. Better onboarding:
   - first-run sample plan
   - guided first session

### Phase D — Optional Sync (CloudKit Decision Gate)
Only proceed if local product quality is stable and test coverage is solid.

CloudKit go/no-go criteria:
- clear user value (multi-device sync demand)
- migration strategy finalized
- conflict resolution UX defined
- recovery/backup plan tested

## Delivery Model (How We Work)
- Jarvis owns coding + technical implementation.
- Gabe owns prioritization, acceptance, and release timing.
- Rule: ship in small, testable slices with explicit acceptance checks.

## Weekly Operating Rhythm
- Mon: prioritize backlog + define acceptance criteria
- Tue-Thu: implementation + iterative QA
- Fri: release candidate cut + decision (ship/hold)

## KPI Suggestions
- Crash-free sessions
- Weekly active usage
- Session completion rate
- Average workouts/week per active user
- 7-day return rate
