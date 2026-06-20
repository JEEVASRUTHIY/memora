const functions = require("firebase-functions");
const admin = require("firebase-admin");
const express = require("express");
const cors = require("cors");

// Initialize Firebase Admin SDK
admin.initializeApp();
const db = admin.firestore();

const app = express();

// Automatically allow cross-origin requests
app.use(cors({ origin: true }));
app.use(express.json());

/**
 * POST /users/register
 * Request Body:
 * {
 *   "userId": "string",
 *   "role": "Patient" | "Caregiver",
 *   "name": "string",
 *   "contactDetails": "string"
 * }
 */
app.post("/register", async (req, res) => {
  try {
    const { userId, role, name, contactDetails } = req.body;

    // Validation
    if (!userId || !role || !name || !contactDetails) {
      return res.status(400).json({ error: "Missing required fields: userId, role, name, contactDetails" });
    }

    if (role !== "Patient" && role !== "Caregiver") {
      return res.status(400).json({ error: "Role must be either 'Patient' or 'Caregiver'" });
    }

    const userDocRef = db.collection("users").doc(userId);

    const userData = {
      userId,
      role,
      name,
      contactDetails,
      linkedPatientId: null,
      linkedCaregiverId: null,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
    };

    // Save to Firestore
    await userDocRef.set(userData);

    return res.status(201).json({
      message: "User registered successfully",
      user: userData,
    });
  } catch (error) {
    console.error("Error in /register:", error);
    return res.status(500).json({ error: error.message });
  }
});

/**
 * POST /users/link-patient
 * Request Body:
 * {
 *   "caregiverId": "string",
 *   "patientId": "string"
 * }
 */
app.post("/link-patient", async (req, res) => {
  try {
    const { caregiverId, patientId } = req.body;

    // Validation
    if (!caregiverId || !patientId) {
      return res.status(400).json({ error: "Missing required fields: caregiverId, patientId" });
    }

    const caregiverRef = db.collection("users").doc(caregiverId);
    const patientRef = db.collection("users").doc(patientId);

    // Atomically link using a transaction
    await db.runTransaction(async (transaction) => {
      const caregiverDoc = await transaction.get(caregiverRef);
      const patientDoc = await transaction.get(patientRef);

      if (!caregiverDoc.exists) {
        throw new Error(`Caregiver user with ID ${caregiverId} does not exist`);
      }
      if (!patientDoc.exists) {
        throw new Error(`Patient user with ID ${patientId} does not exist`);
      }

      const caregiverData = caregiverDoc.data();
      const patientData = patientDoc.data();

      // Verify roles
      if (caregiverData.role !== "Caregiver") {
        throw new Error(`User with ID ${caregiverId} is not registered as a Caregiver`);
      }
      if (patientData.role !== "Patient") {
        throw new Error(`User with ID ${patientId} is not registered as a Patient`);
      }

      // Verify they are not already linked to other people
      if (caregiverData.linkedPatientId && caregiverData.linkedPatientId !== patientId) {
        throw new Error(`Caregiver user with ID ${caregiverId} is already linked to another patient`);
      }
      if (patientData.linkedCaregiverId && patientData.linkedCaregiverId !== caregiverId) {
        throw new Error(`Patient user with ID ${patientId} is already linked to another caregiver`);
      }

      // Perform updates
      transaction.update(caregiverRef, { linkedPatientId: patientId });
      transaction.update(patientRef, { linkedCaregiverId: caregiverId });
    });

    return res.status(200).json({
      message: "Caregiver and Patient successfully linked",
      caregiverId,
      patientId,
    });
  } catch (error) {
    console.error("Error in /link-patient:", error);
    return res.status(500).json({ error: error.message });
  }
});

// Expose Express App as a single Cloud Function named "users"
exports.users = functions.https.onRequest(app);

/**
 * Trigger when a reminder log is created.
 * If status is 'Triggered', it looks up the patient's fcmToken and sends a push notification.
 */
exports.onReminderLogCreated = functions.firestore
  .document("reminderLogs/{logId}")
  .onCreate(async (snapshot, context) => {
    const logData = snapshot.data();
    if (!logData) return null;

    if (logData.status === "Triggered") {
      const patientId = logData.patientId;
      if (!patientId) return null;

      try {
        const patientDoc = await db.collection("users").doc(patientId).get();
        if (!patientDoc.exists) return null;

        const fcmToken = patientDoc.data().fcmToken;
        if (!fcmToken) {
          console.log(`No fcmToken found for patient: ${patientId}`);
          return null;
        }

        const payload = {
          token: fcmToken,
          notification: {
            title: `${logData.reminderType} Reminder`,
            body: logData.description,
          },
          data: {
            logId: snapshot.id,
            reminderId: logData.reminderId || "",
            patientId: logData.patientId || "",
            reminderType: logData.reminderType || "",
            description: logData.description || "",
            instructions: logData.instructions || "",
            snoozeEnabled: String(logData.snoozeEnabled !== false),
            click_action: "FLUTTER_NOTIFICATION_CLICK",
          },
        };

        const response = await admin.messaging().send(payload);
        console.log("Successfully sent reminder push:", response);
        return response;
      } catch (error) {
        console.error("Error sending reminder push:", error);
      }
    }
    return null;
  });

/**
 * Trigger when a reminder log is updated.
 * If status updates to 'Missed' and escalationNotified is true,
 * it looks up the caregiver's fcmToken and sends a push notification.
 */
exports.onReminderLogUpdated = functions.firestore
  .document("reminderLogs/{logId}")
  .onUpdate(async (change, context) => {
    const beforeData = change.before.data();
    const afterData = change.after.data();
    if (!beforeData || !afterData) return null;

    const becameMissed = afterData.status === "Missed" && beforeData.status !== "Missed";
    const becameEscalated = afterData.escalationNotified === true && beforeData.escalationNotified !== true;

    // Send push if log became missed and escalated
    if (afterData.status === "Missed" && afterData.escalationNotified === true && 
        (becameMissed || becameEscalated)) {
      const patientId = afterData.patientId;
      if (!patientId) return null;

      try {
        // Fetch patient to get linkedCaregiverId
        const patientDoc = await db.collection("users").doc(patientId).get();
        if (!patientDoc.exists) return null;

        const caregiverId = patientDoc.data().linkedCaregiverId;
        if (!caregiverId) {
          console.log(`No caregiver linked to patient: ${patientId}`);
          return null;
        }

        // Fetch caregiver to get fcmToken
        const caregiverDoc = await db.collection("users").doc(caregiverId).get();
        if (!caregiverDoc.exists) return null;

        const caregiverFcmToken = caregiverDoc.data().fcmToken;
        if (!caregiverFcmToken) {
          console.log(`No fcmToken found for caregiver: ${caregiverId}`);
          return null;
        }

        const payload = {
          token: caregiverFcmToken,
          notification: {
            title: `Missed Reminder: ${afterData.reminderType}`,
            body: `${patientDoc.data().name || "Your patient"} missed: ${afterData.description}`,
          },
          data: {
            logId: change.after.id,
            reminderId: afterData.reminderId || "",
            patientId: afterData.patientId || "",
            reminderType: afterData.reminderType || "",
            description: afterData.description || "",
            instructions: afterData.instructions || "",
            click_action: "FLUTTER_NOTIFICATION_CLICK",
          },
        };

        const response = await admin.messaging().send(payload);
        console.log("Successfully sent caregiver escalation push:", response);
        return response;
      } catch (error) {
        console.error("Error sending caregiver escalation push:", error);
      }
    }
    return null;
  });
