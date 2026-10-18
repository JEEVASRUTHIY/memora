/**
 * One-time migration script: upgrade existing links to multi-caregiver format.
 * 
 * Run with:
 *   npx ts-node scripts/migrate_links.ts
 * 
 * Requires GOOGLE_APPLICATION_CREDENTIALS to be set, or run from a
 * service-account environment.
 *
 * Each existing link that is missing `role` becomes:
 *   role: 'primary', priority: 1, status: 'active'
 * and a caregiverLinks/{caregiverUid}/patients/{patientId} index is written.
 */

import { initializeApp, cert, ServiceAccount } from 'firebase-admin/app';
import { getFirestore, Timestamp } from 'firebase-admin/firestore';

// eslint-disable-next-line @typescript-eslint/no-var-requires
const serviceAccount: ServiceAccount = require('../../service-account.json');

initializeApp({ credential: cert(serviceAccount) });
const db = getFirestore();

async function run(): Promise<void> {
  const snap = await db.collection('links').get();
  let migrated = 0;
  let skipped = 0;

  for (const doc of snap.docs) {
    const data = doc.data();

    // Skip docs that already have the new schema
    if (data.role) {
      skipped++;
      continue;
    }

    const patientId: string = data.patientId ?? '';
    const caregiverUid: string = data.caregiverUid ?? '';

    const batch = db.batch();

    // Upgrade the link doc
    batch.update(doc.ref, {
      role: 'primary',
      priority: 1,
      status: data.status ?? 'active',
    });

    // Write the caregiverLinks secondary index
    const indexRef = db
      .collection('caregiverLinks')
      .doc(caregiverUid)
      .collection('patients')
      .doc(patientId);
    batch.set(indexRef, {
      patientUid: data.patientUid ?? '',
      linkId: doc.id,
      role: 'primary',
      linkedAt: data.createdAt ?? Timestamp.now(),
    });

    await batch.commit();
    migrated++;
    console.log(`[✓] Migrated link ${doc.id} (caregiver=${caregiverUid}, patient=${patientId})`);
  }

  console.log(`\nDone. Migrated: ${migrated}  Skipped (already new): ${skipped}`);
}

run().catch((e) => {
  console.error('Migration failed:', e);
  process.exit(1);
});
