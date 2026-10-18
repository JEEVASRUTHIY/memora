# Memora — BASE-1 Progress

**Last updated:** 2026-10-17  
**Current phase:** Phase 1 — Foundation  
**NEXT ACTION:** IN PROGRESS — Phase 1 housekeeping & structure

---

## Step Table

| Step | Status | Files | Notes |
|---|---|---|---|
| **HOUSEKEEPING A1** — flutter analyze + fix | DONE | auth_providers.dart | No issues |
| **HOUSEKEEPING A2** — delete MASTER_PLAN.md, archive old PROGRESS.md, fresh PROGRESS.md | DONE | docs/archive/, PROGRESS.md | archived |
| **HOUSEKEEPING A3** — delete lib/functions_helpers/, remove notifyUsers CF | DONE | functions/src/index.ts, sendToUsers.ts | notifyUsers removed, helper extracted |
| **HOUSEKEEPING A4** — clean firestore.indexes.json (remove stale, add coll-group index) | DONE | firestore.indexes.json | collection-group index added |
| **PH1-1** — folder structure (features/, core/ subdirs, extension folders + READMEs) | IN PROGRESS | lib/ | — |
| **PH1-2** — design system (AppTheme light/M3, patient + caregiver themes, shared widgets) | TODO | lib/core/theme/, lib/core/widgets/ | — |
| **PH1-3** — feature_flags.dart, app_config.dart | TODO | lib/core/ | — |
| **PH1-4** — go_router setup (auth redirect, role guard, shell routes) | TODO | lib/core/router/ | — |
| **PH1-5** — Android: minSdk 26, permissions cleanup, Maps placeholder, functions predeploy | TODO | android/, functions/package.json | — |
| **PH1-6** — docs skeletons (ARCHITECTURE.md, DATA_MODEL.md, CONTRIBUTING.md, pr template) | TODO | docs/, .github/ | — |
| **PH1-7** — flutter analyze clean + functions build clean | TODO | — | — |
| **PH1-8** — End-of-phase checks + commit + STOP | TODO | — | — |

---

## Manual Steps Pending for the User

_(To be filled at end of each phase)_

---

## Known Issues

- `functions/lib/` (compiled JS) is not committed — deploy requires `npm run build` first (predeploy hook to be added).
- Maps API key is empty — must be set in `android/local.properties` as `MAPS_API_KEY=<your_key>`.
- Release signing uses debug keys — acceptable for test APKs; production keystore is future work.
