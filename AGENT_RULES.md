# AGENT RULES (read at the start of every prompt)
Project: MEMORA, Flutter+Riverpod+go_router, Firebase (Auth, Firestore,
Cloud Functions TS, FCM, Storage). Roles PATIENT/CAREGIVER linked by patient
ID. Each patient: 1 primary + up to 3 secondary caregivers (pending until
approved). Real Android phones only.
RULES
1. At the start of every prompt: read AGENT_RULES.md and PROGRESS.md, check
   `git log --oneline -10`, and continue from the first unfinished step.
   Check the real code, not just the file: if a step is already done, mark
   it done and reuse it.
2. Do steps in order. Before starting a step, write "IN PROGRESS: <step>" in
   PROGRESS.md and commit. After finishing, write "DONE: <step>" and commit.
   Commit after every sub-part, so work is never lost if credits end.
3. Do not rewrite or refactor code that already works. Keep code compact.
4. Run `flutter analyze` after each step. Build the release APK only once,
   at the end of each prompt.
5. Never print, hardcode, or commit API keys. Keys live only in
   android/local.properties (MAPS_API_KEY) and Firebase secrets
   (GEMINI_API_KEY, NVIDIA_API_KEY). Check .gitignore covers local.properties,
   .env and any service-account JSON.
6. Do not claim anything works on a device. Never say "tested" unless you
   actually ran it.
7. Short docs only: a README section and a short docs/rules_tests.md.
END-OF-PROMPT CHECKS (do at the end of every prompt)
a. `flutter analyze` clean.
b. `flutter build apk --release`; report the exact path
   (build/app/outputs/flutter-apk/app-release.apk).
c. Confirm the MAIN android/app/src/main/AndroidManifest.xml has every
   permission used so far (INTERNET, POST_NOTIFICATIONS, exact alarm,
   location, foreground service, camera/photo if used).
d. Update PROGRESS.md and commit.
e. Give me: manual steps I must do (deploy commands, secrets, SHA-1, enable
   Maps/Storage) and a 3-line phone test checklist.
