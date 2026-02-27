# Engineering Playbook (Coder Context)

This is the standing context for ongoing development where Jarvis is primary implementer.

## Architecture Principles
1. Local-first by default.
2. Reliability over feature volume.
3. DesignKit is source of truth for visual language.
4. Add cloud complexity only when product value clearly demands it.

## Coding Standards
- Favor explicit, readable Swift over clever abstractions.
- Validate at boundaries (user input, import/export, startup bootstrap).
- Fail gracefully with user-facing recovery paths.
- Keep domain logic in services/view models, not in view bodies.

## UI/UX Standards
- Use DesignKit components/tokens for consistency.
- Avoid visually narrow centered layouts unless intentional.
- Every major surface should have:
  - content state
  - empty state
  - error state (where applicable)
- Respect accessibility:
  - Dynamic Type compatibility
  - meaningful accessibility labels
  - sufficient contrast

## Data & Persistence Standards
- SwiftData local store is canonical for now.
- Track schema version changes (`StorageVersionService`).
- For seed updates:
  - merge missing items
  - avoid duplicates
  - never destroy user data silently

## Release Checklist (Every RC)
1. Build app and verify launch from fresh install.
2. Validate core flow:
   - start workout
   - add exercise/set
   - end workout
   - review history/progress
3. Validate Settings:
   - theme changes
   - export/import backup
4. Validate empty states and errors are user-friendly.
5. Confirm no debug artifacts or placeholder strings remain.

## Backlog Buckets
- P0: crashes, data loss, broken critical flow
- P1: high-friction UX, accessibility blockers
- P2: enhancements and polish

## Branch / Commit Guidance
- Small, focused commits with clear intent.
- Suggested prefixes:
  - `fix:` reliability/bug
  - `feat:` user-visible capability
  - `chore:` infrastructure/docs

## CloudKit Future (When activated)
- Keep sync layer additive, not invasive.
- Start with one-way sync experiments on non-critical data.
- Implement conflict policy before broad rollout.
