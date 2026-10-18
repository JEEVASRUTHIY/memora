# Phone testing

Phase 1 checklist (real Android 8+ phones; not yet run by the agent):
1. Open the release APK, visit welcome/login/signup, log in as patient and caregiver on separate phones; verify each lands on its role home and survives restart.
2. Open caregiver navigation and sign out from a nested screen; back must not expose patient data. Pending caregivers stay on their waiting screen.
3. On the patient home tap the version five times; developer tools opens with disabled future actions. Check readable text and no overflow on both phones.

Later acceptance (run only after that phase):
- Phase 2: patient ID, primary linking, backup by email/invite, approval and fourth-backup refusal; pending users cannot read data.
- Phase 3: 200 m zone, walk about 300 m away; one alert to all active caregivers, back-inside alert, patient warning, acknowledgement.
- Phase 4: reminder in two minutes, repeats/missed alert, Done survives re-login, Later returns after ten minutes, patient-edit restrictions.
- Phase 5: full two-phone regression; internet required for reminders; debug-signed APKs are for testing only.
