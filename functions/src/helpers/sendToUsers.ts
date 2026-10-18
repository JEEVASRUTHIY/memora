import { getFirestore, FieldValue } from 'firebase-admin/firestore';
import { getMessaging } from 'firebase-admin/messaging';

/**
 * Sends a high-priority FCM data message to all tokens for each uid.
 * Removes any token that FCM reports as unregistered/invalid.
 */
export async function sendToUsers(
  uids: string[],
  payload: Record<string, string>
): Promise<void> {
  if (uids.length === 0) return;
  const db = getFirestore();
  const messaging = getMessaging();

  await Promise.all(
    uids.map(async (uid) => {
      const userSnap = await db.collection('users').doc(uid).get();
      if (!userSnap.exists) return;
      const tokens: string[] = userSnap.data()?.fcmTokens ?? [];
      if (tokens.length === 0) return;

      const results = await Promise.allSettled(
        tokens.map((token) =>
          messaging.send({
            token,
            data: payload,
            android: { priority: 'high' },
          })
        )
      );

      const badTokens: string[] = [];
      results.forEach((r, i) => {
        if (r.status === 'rejected') {
          const code: string = (r.reason as any)?.errorInfo?.code ?? '';
          if (
            code === 'messaging/registration-token-not-registered' ||
            code === 'messaging/invalid-registration-token'
          ) {
            badTokens.push(tokens[i]);
          }
        }
      });

      if (badTokens.length > 0) {
        await db.collection('users').doc(uid).update({
          fcmTokens: FieldValue.arrayRemove(...badTokens),
        });
      }
    })
  );
}
