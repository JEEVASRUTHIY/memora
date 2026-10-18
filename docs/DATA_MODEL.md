# Data model

BASE-2 target; this is a schema guide, not a claim that migrations are deployed.
The 6-character patient ID is `pid`; Firebase Auth UID is `uid`.

| Path | Fields / access |
|---|---|
| users/{uid} | role (immutable), name, email, patientId, fcmTokens[], timezone, createdAt; owner only |
| patients/{pid} | ownerUid, name, timezone, primaryCaregiverUid, createdAt; Phase 2 atomic registration with users doc and uniqueness check; backfill existing patients |
| links/{id} | patientId, caregiverUid, caregiverName, role primary/secondary, status pending/active/rejected/removed, requestedBy, createdAt, respondedAt; Functions write only |
| caregiverLinks/{uid}/patients/{pid} | Denormalized link index; every link function keeps it synchronized |
| patients/{pid}/safeZones/current | centerLat, centerLng, radiusMeters, enabled, updatedBy, updatedAt; active primary writes |
| patients/{pid}/status/live | lat, lng, accuracy, insideSafeZone, updatedAt; patient writes |
| patients/{pid}/alerts/{id} | type, message, lat/lng, audience all/primary, severity, createdAt, notifiedUids, acknowledgedBy/At; active caregivers acknowledge only |
| patients/{pid}/reminders/{rid} | Preserve existing fields; add type, weekdays (1–7), patientCanEdit, maxRepeats, repeatEveryMinutes, snoozeMinutes, createdByRole |
| patients/{pid}/reminderOccurrences/{rid_yyyyMMddHHmm} | reminderId, title, type, scheduledTime, status, nextNotifyAt, repeatCount, snoozeCount, shownTime, respondedAt, missedAlerted |
| patients/{pid}/reminderEvents/{id} | occurrenceId, reminderId, type, scheduledTime, shownTime, responseTime, responseDelaySeconds, action, repeatCount, snoozeCount, hourOfDay, createdAt; create-only |

Current legacy links also use patientUid, priority, approvedBy/At. Phase 2 preserves compatibility while adding the root doc and new fields. Current user registration is not yet atomic. PatientId is assigned at creation and immutable thereafter; rules must validate the atomic owner/root pair.

Phase 4 migrates reminder defaults, cleans future pending occurrences, and replaces legacy snoozedUntil/status event fields. Do not run ad-hoc destructive migrations.

Indexes currently cover occurrence status + scheduledTime (collection) and status + nextNotifyAt (collection group). Other current filters use automatic single-field indexes/equality merging. Add indexes alongside new queries; do not restore stale reminderLogs/locationLogs/dailyBehavior/weeklySummaries indexes.
