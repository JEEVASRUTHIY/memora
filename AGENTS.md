1. Start of every session: read AGENTS.md, docs/BASE_PLAN.md and PROGRESS.md,
   check `git log --oneline -10`, continue from the first unfinished step. Check
   the real code, not only the file.
2. Before a step write "IN PROGRESS: <step>" in PROGRESS.md and commit; after it
   write "DONE: <step>" and commit. Commit after every sub-part.
3. Reuse existing code that is good (see docs/STATUS.md). Rewrite only what the
   plan changes. Delete dead code (git history keeps it). Keep code compact.
4. Run `flutter analyze` after each step. Build the release APK once at the end
   of each phase.
5. Never print, hardcode or commit API keys or service-account files. The Maps
   key lives only in android/local.properties (MAPS_API_KEY). Keep
   local.properties, .env and key files in .gitignore.
6. Never claim anything works on a device or in Firebase unless you actually ran
   it. Do not push to any remote.
7. Docs are short. PROGRESS.md format: header (last updated, current phase, NEXT
   ACTION), a table (step | TODO / IN PROGRESS / DONE | files | notes), and
   sections "Manual steps pending for the user" and "Known issues".


## Commands
- `flutter analyze`
- `cd functions && npm run build`
- read docs/BASE_PLAN.md and PROGRESS.md at the start of every session
- Stop after each phase and wait for the user to say continue.
