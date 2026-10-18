import { initializeApp } from 'firebase-admin/app';
import { getFirestore, Timestamp } from 'firebase-admin/firestore';
import { onCall, CallableRequest, HttpsError } from 'firebase-functions/v2/https';
import { onSchedule } from 'firebase-functions/v2/scheduler';
import { onDocumentCreated } from 'firebase-functions/v2/firestore';
import {
  format, addDays, addMinutes,
  setHours, setMinutes, setSeconds, setMilliseconds,
} from 'date-fns';
import { sendToUsers } from './helpers/sendToUsers';

initializeApp();
const db = getFirestore();

// ─── Types ────────────────────────────────────────────────────────────────────

interface LinkDoc {
  patientUid: string;
  caregiverUid: string;
  patientId: string;
  role: 'primary' | 'secondary';
  priority: 1 | 2 | 3 | 4;
  status: 'pending' | 'active' | 'rejected' | 'removed';
  approvedBy?: string;
  approvedAt?: Timestamp;
  createdAt: Timestamp;
}

interface ReminderDoc {
  patientId: string;
  title: string;
  note?: string;
  imageUrl?: string;
  recurrence: 'once' | 'daily' | 'weekly';
  times: string[];          // ["HH:mm", ...]
  weekdays?: number[];      // 1=Mon … 7=Sun (ISO)
  importance: 'low' | 'medium' | 'high';
  maxRepeats: number;       // default 3
  repeatEveryMinutes: number; // default 5
  snoozeMinutes: number;    // default 10
  active: boolean;
  patientCanEdit: boolean;  // default true
  createdBy: string;
  createdByRole: 'patient' | 'caregiver';
  createdAt: Timestamp;
}

interface OccurrenceDoc {
  reminderId: string;
  scheduledTime: Timestamp;
  status: 'pending' | 'confirmed' | 'snoozed' | 'missed';
  nextNotifyAt: Timestamp;
  repeatCount: number;
  snoozeCount: number;
  missedAlerted: boolean;
  shownTime?: Timestamp;
  respondedAt?: Timestamp;
}

// ─── Helper: get active primary link for a patient ────────────────────────────

async function getPrimaryLink(
  patientUid: string
): Promise<FirebaseFirestore.QueryDocumentSnapshot | null> {
  const snap = await db.collection('links')
    .where('patientUid', '==', patientUid)
    .where('role', '==', 'primary')
    .where('status', '==', 'active')
    .limit(1)
    .get();
  return snap.empty ? null : snap.docs[0];
}

// ─── Callable: requestLink ────────────────────────────────────────────────────

export const requestLink = onCall(
  async (request: CallableRequest<{ patientId: string }>) => {
    if (!request.auth) throw new HttpsError('unauthenticated', 'Must be signed in.');

    const caregiverUid = request.auth.uid;
    const { patientId } = request.data;
    if (!patientId) throw new HttpsError('invalid-argument', 'patientId is required.');

    const callerSnap = await db.collection('users').doc(caregiverUid).get();
    if (!callerSnap.exists || callerSnap.data()?.role !== 'caregiver') {
      throw new HttpsError('permission-denied', 'Only caregivers can request links.');
    }

    const patientQuery = await db.collection('users')
      .where('patientId', '==', patientId.toUpperCase())
      .where('role', '==', 'patient')
      .limit(1)
      .get();
    if (patientQuery.empty) {
      throw new HttpsError('not-found', `No patient with ID "${patientId}".`);
    }
    const patientDoc = patientQuery.docs[0];
    const patientUid = patientDoc.id;

    // Reject duplicate
    const dupSnap = await db.collection('links')
      .where('patientUid', '==', patientUid)
      .where('caregiverUid', '==', caregiverUid)
      .where('status', 'in', ['pending', 'active'])
      .limit(1)
      .get();
    if (!dupSnap.empty) {
      throw new HttpsError('already-exists', 'You are already linked or pending for this patient.');
    }

    const existingSnap = await db.collection('links')
      .where('patientUid', '==', patientUid)
      .where('status', 'in', ['pending', 'active'])
      .get();

    const existingDocs = existingSnap.docs;
    const hasPrimary = existingDocs.some((d) => d.data().role === 'primary');
    const secondaryCount = existingDocs.filter((d) => d.data().role === 'secondary').length;

    if (!hasPrimary) {
      // First caregiver → primary + active
      const linkRef = db.collection('links').doc();
      const linkData: LinkDoc = {
        patientUid, caregiverUid,
        patientId: patientId.toUpperCase(),
        role: 'primary', priority: 1, status: 'active',
        createdAt: Timestamp.now(),
      };
      await linkRef.set(linkData);
      await db.collection('caregiverLinks').doc(caregiverUid)
        .collection('patients').doc(patientId.toUpperCase())
        .set({ patientUid, linkId: linkRef.id, role: 'primary', linkedAt: Timestamp.now() });
      return { linkId: linkRef.id, role: 'primary', status: 'active' };
    }

    // Enforce max 3 secondaries (pending + active)
    if (secondaryCount >= 3) {
      throw new HttpsError(
        'resource-exhausted',
        'Patient already has 3 backup caregivers (active or pending).'
      );
    }

    const linkRef = db.collection('links').doc();
    const linkData: LinkDoc = {
      patientUid, caregiverUid,
      patientId: patientId.toUpperCase(),
      role: 'secondary', priority: 1, status: 'pending',
      createdAt: Timestamp.now(),
    };
    await linkRef.set(linkData);

    // Notify primary caregiver
    const primaryLink = await getPrimaryLink(patientUid);
    if (primaryLink) {
      const callerName = callerSnap.data()?.name ?? 'A caregiver';
      await sendToUsers([primaryLink.data().caregiverUid], {
        type: 'newLinkRequest', linkId: linkRef.id, caregiverName: callerName,
      });
    }

    return { linkId: linkRef.id, role: 'secondary', status: 'pending' };
  }
);

// ─── Callable: respondToLink ──────────────────────────────────────────────────

export const respondToLink = onCall(
  async (request: CallableRequest<{ linkId: string; approve: boolean }>) => {
    if (!request.auth) throw new HttpsError('unauthenticated', 'Must be signed in.');

    const callerUid = request.auth.uid;
    const { linkId, approve } = request.data;
    if (!linkId) throw new HttpsError('invalid-argument', 'linkId is required.');

    const linkRef = db.collection('links').doc(linkId);
    const linkSnap = await linkRef.get();
    if (!linkSnap.exists) throw new HttpsError('not-found', 'Link not found.');

    const link = linkSnap.data() as LinkDoc;
    if (link.status !== 'pending') {
      throw new HttpsError('failed-precondition', 'Link is not pending.');
    }

    const primaryLink = await getPrimaryLink(link.patientUid);
    if (!primaryLink || primaryLink.data().caregiverUid !== callerUid) {
      throw new HttpsError('permission-denied', 'Only the primary caregiver can approve or reject links.');
    }

    if (!approve) {
      await linkRef.update({ status: 'rejected' });
      await sendToUsers([link.caregiverUid], { type: 'linkRejected', linkId });
      return { status: 'rejected' };
    }

    // Assign next free priority slot
    const activeSecondaries = await db.collection('links')
      .where('patientUid', '==', link.patientUid)
      .where('role', '==', 'secondary')
      .where('status', '==', 'active')
      .get();
    const usedPriorities = new Set(activeSecondaries.docs.map((d) => d.data().priority as number));
    let freePriority: 2 | 3 | 4 | null = null;
    for (const p of [2, 3, 4] as const) {
      if (!usedPriorities.has(p)) { freePriority = p; break; }
    }
    if (freePriority === null) {
      throw new HttpsError('resource-exhausted', 'All secondary priority slots are already filled.');
    }

    await linkRef.update({
      status: 'active', priority: freePriority,
      approvedBy: callerUid, approvedAt: Timestamp.now(),
    });
    await db.collection('caregiverLinks').doc(link.caregiverUid)
      .collection('patients').doc(link.patientId)
      .set({ patientUid: link.patientUid, linkId, role: 'secondary', linkedAt: Timestamp.now() });

    await sendToUsers([link.caregiverUid], {
      type: 'linkApproved', linkId, priority: String(freePriority),
    });
    return { status: 'active', priority: freePriority };
  }
);

// ─── Callable: removeSecondary ────────────────────────────────────────────────

export const removeSecondary = onCall(
  async (request: CallableRequest<{ linkId: string }>) => {
    if (!request.auth) throw new HttpsError('unauthenticated', 'Must be signed in.');

    const callerUid = request.auth.uid;
    const { linkId } = request.data;
    if (!linkId) throw new HttpsError('invalid-argument', 'linkId is required.');

    const linkRef = db.collection('links').doc(linkId);
    const linkSnap = await linkRef.get();
    if (!linkSnap.exists) throw new HttpsError('not-found', 'Link not found.');

    const link = linkSnap.data() as LinkDoc;
    if (link.role !== 'secondary') {
      throw new HttpsError('failed-precondition', 'Can only remove secondary links.');
    }
    if (link.status === 'removed') {
      throw new HttpsError('failed-precondition', 'Link is already removed.');
    }

    const primaryLink = await getPrimaryLink(link.patientUid);
    if (!primaryLink || primaryLink.data().caregiverUid !== callerUid) {
      throw new HttpsError('permission-denied', 'Only the primary caregiver can remove backup caregivers.');
    }

    await linkRef.update({ status: 'removed' });
    await db.collection('caregiverLinks').doc(link.caregiverUid)
      .collection('patients').doc(link.patientId)
      .delete();
    await sendToUsers([link.caregiverUid], { type: 'linkRemoved', linkId });
    return { status: 'removed' };
  }
);

// ─── Trigger: onAlertCreated ──────────────────────────────────────────────────
// Sends FCM push to the appropriate caregivers when an alert doc is created.

export const onAlertCreated = onDocumentCreated(
  'patients/{patientId}/alerts/{alertId}',
  async (event) => {
    const alert = event.data?.data();
    if (!alert) return;

    const patientId = event.params.patientId;

    // Resolve patientUid from patientId
    const patientQuery = await db.collection('users')
      .where('patientId', '==', patientId)
      .where('role', '==', 'patient')
      .limit(1)
      .get();
    if (patientQuery.empty) return;
    const patientUid = patientQuery.docs[0].id;
    const patientName = patientQuery.docs[0].data().name ?? 'Your patient';

    // Find active caregivers
    const linksQuery = db.collection('links')
      .where('patientUid', '==', patientUid)
      .where('status', '==', 'active');
    const linksSnap = await linksQuery.get();
    if (linksSnap.empty) return;

    let uids: string[];
    if (alert.audience === 'primary') {
      uids = linksSnap.docs
        .filter((d) => d.data().role === 'primary')
        .map((d) => d.data().caregiverUid as string);
    } else {
      uids = linksSnap.docs.map((d) => d.data().caregiverUid as string);
    }
    if (uids.length === 0) return;

    const typeMessages: Record<string, string> = {
      outsideSafeZone: `${patientName} has left the safe zone`,
      backInside: `${patientName} is back inside the safe zone`,
      missedReminder: `${patientName} missed a reminder`,
      sos: `SOS from ${patientName}`,
    };
    const message = typeMessages[alert.type] ?? alert.message ?? 'New alert';

    await sendToUsers(uids, {
      type: alert.type,
      patientId,
      alertId: event.params.alertId,
      message,
    });

    // Record notifiedUids on the alert
    await event.data!.ref.update({ notifiedUids: uids });
  }
);

// ─── Scheduled: generateOccurrences (every 15 min) ───────────────────────────
// Generates reminder occurrences 48 h ahead. Idempotent (create-if-absent).
// Fixes the weekly bug: uses the reminder's weekdays[] array (ISO 1=Mon … 7=Sun).

export const generateOccurrences = onSchedule('every 15 minutes', async () => {
  const now = new Date();
  const windowEnd = addDays(now, 2);

  const patientsSnap = await db.collection('users')
    .where('role', '==', 'patient')
    .get();

  for (const patientDoc of patientsSnap.docs) {
    const patientUid = patientDoc.id;
    const patientId = patientDoc.data().patientId as string | undefined;
    if (!patientId) continue;

    const remindersSnap = await db.collection('patients').doc(patientUid)
      .collection('reminders')
      .where('active', '==', true)
      .get();

    for (const reminderDoc of remindersSnap.docs) {
      const rid = reminderDoc.id;
      const rem = reminderDoc.data() as ReminderDoc;
      const times = rem.times?.length ? rem.times : ['09:00'];
      const occurrenceTimes = computeOccurrenceTimes(rem, times, now, windowEnd);

      for (const occTime of occurrenceTimes) {
        const occId = `${rid}_${formatOccId(occTime)}`;
        const occRef = db.collection('patients').doc(patientUid)
          .collection('reminderOccurrences').doc(occId);

        await db.runTransaction(async (tx) => {
          const snap = await tx.get(occRef);
          if (!snap.exists) {
            tx.set(occRef, {
              reminderId: rid,
              scheduledTime: Timestamp.fromDate(occTime),
              status: 'pending',
              nextNotifyAt: Timestamp.fromDate(occTime),
              repeatCount: 0,
              snoozeCount: 0,
              missedAlerted: false,
            } satisfies OccurrenceDoc);
          }
        });
      }
    }
  }
});

// ─── Scheduled: dispatchReminders (every minute) ─────────────────────────────
// Sends FCM to the patient for each due occurrence. Updates state transactionally.

export const dispatchReminders = onSchedule('every 1 minutes', async () => {
  const now = Timestamp.now();

  // Collection-group query: pending|snoozed, nextNotifyAt <= now
  const occSnap = await db.collectionGroup('reminderOccurrences')
    .where('status', 'in', ['pending', 'snoozed'])
    .where('nextNotifyAt', '<=', now)
    .get();

  for (const occDoc of occSnap.docs) {
    const occ = occDoc.data() as OccurrenceDoc;
    const occRef = occDoc.ref;

    // Resolve patientUid from path: patients/{uid}/reminderOccurrences/{occId}
    const patientUid = occDoc.ref.parent.parent?.id;
    if (!patientUid) continue;

    // Get the reminder to read maxRepeats / repeatEveryMinutes / snoozeMinutes
    const reminderRef = db.collection('patients').doc(patientUid)
      .collection('reminders').doc(occ.reminderId);
    const reminderSnap = await reminderRef.get();
    if (!reminderSnap.exists) continue;
    const rem = reminderSnap.data() as ReminderDoc;
    const maxRepeats = rem.maxRepeats ?? 3;
    const repeatEveryMinutes = rem.repeatEveryMinutes ?? 5;

    // Look up patient's FCM tokens
    const userSnap = await db.collection('users').doc(patientUid).get();
    if (!userSnap.exists) continue;
    const patientId = userSnap.data()?.patientId as string | undefined;
    if (!patientId) continue;

    await db.runTransaction(async (tx) => {
      const freshOcc = await tx.get(occRef);
      if (!freshOcc.exists) return;
      const freshData = freshOcc.data() as OccurrenceDoc;
      // Guard: another invocation may have already handled this
      if (!['pending', 'snoozed'].includes(freshData.status)) return;
      if (freshData.nextNotifyAt.toMillis() > now.toMillis()) return;

      const newRepeatCount = freshData.repeatCount + 1;
      const isFirst = freshData.repeatCount === 0;

      if (newRepeatCount < maxRepeats) {
        const nextNotify = addMinutes(now.toDate(), repeatEveryMinutes);
        tx.update(occRef, {
          repeatCount: newRepeatCount,
          ...(isFirst ? { shownTime: now } : {}),
          nextNotifyAt: Timestamp.fromDate(nextNotify),
        });
      } else {
        // Mark missed
        tx.update(occRef, {
          status: 'missed',
          repeatCount: newRepeatCount,
          missedAlerted: true,
        });
        // Create missedReminder alert for the primary caregiver
        const alertRef = db.collection('patients').doc(patientUid)
          .collection('alerts').doc();
        tx.set(alertRef, {
          type: 'missedReminder',
          message: `Missed reminder: ${rem.title}`,
          audience: 'primary',
          severity: 'medium',
          reminderId: occ.reminderId,
          occurrenceId: occDoc.id,
          createdAt: now,
          acknowledged: false,
          notifiedUids: [],
        });
      }
    });

    // Send FCM (outside transaction to avoid contention)
    await sendToUsers([patientUid], {
      type: 'reminder',
      occurrenceId: occDoc.id,
      patientId,
      channelId: 'memora_reminders_v2',
    });
  }
});

// ─── Helpers ──────────────────────────────────────────────────────────────────

function formatOccId(d: Date): string {
  return format(d, 'yyyyMMddHHmm');
}

function computeOccurrenceTimes(
  rem: ReminderDoc,
  times: string[],
  now: Date,
  windowEnd: Date
): Date[] {
  const result: Date[] = [];

  function timeOfDayOnDate(base: Date, hhmm: string): Date {
    const [h, m] = hhmm.split(':').map(Number);
    return setMilliseconds(setSeconds(setMinutes(setHours(base, h), m), 0), 0);
  }

  if (rem.recurrence === 'once') {
    for (const t of times) {
      const candidate = timeOfDayOnDate(now, t);
      if (candidate > now && candidate <= windowEnd) result.push(candidate);
    }
    return result;
  }

  let cursor = new Date(now);
  while (cursor <= windowEnd) {
    let shouldFire = false;
    if (rem.recurrence === 'daily') {
      shouldFire = true;
    } else if (rem.recurrence === 'weekly') {
      // ISO weekday: 1=Mon … 7=Sun; JS getDay(): 0=Sun … 6=Sat
      const jsDay = cursor.getDay();
      const isoDay = jsDay === 0 ? 7 : jsDay;
      const weekdays = rem.weekdays && rem.weekdays.length > 0 ? rem.weekdays : [1];
      shouldFire = weekdays.includes(isoDay);
    }
    if (shouldFire) {
      for (const t of times) {
        const candidate = timeOfDayOnDate(cursor, t);
        if (candidate > now && candidate <= windowEnd) result.push(candidate);
      }
    }
    cursor = addDays(cursor, 1);
  }
  return result;
}
