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
