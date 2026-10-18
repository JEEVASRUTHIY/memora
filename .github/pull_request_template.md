---
name: Feature / Bug PR
about: Standard pull request for Memora
---

## What does this PR do?

<!-- One sentence summary -->

## Checklist

- [ ] `flutter analyze` runs with **zero** issues
- [ ] Screens contain no direct Firestore/Firebase calls (Riverpod providers only)
- [ ] New providers use `AsyncNotifier` / `Notifier` (not `StateNotifier`)
- [ ] Feature flag added and defaults to `false` (if this is a new feature)
- [ ] Any changes to `lib/core/` are explained below
- [ ] Firestore security rules updated if new collections/fields were added
- [ ] `docs/DATA_MODEL.md` updated if the data model changed

## Changes to `lib/core/` (if any)

<!-- Explain why core was changed -->

## Manual test steps

<!-- What to test on a phone -->

## Screenshots / screen recordings (optional)
