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

// Token Verification Middleware
const validateFirebaseIdToken = async (req, res, next) => {
  if (process.env.NODE_ENV === 'test') {
    let mockUid = req.headers['x-mock-user-id'];
    if (!mockUid) {
      if (req.path === '/link-patient' || req.path === '/safezone/configure') {
        mockUid = req.body.caregiverId || req.body.userId || req.body.patientId;
      } else if (req.path.startsWith('/safezone/') && req.path !== '/safezone/configure' && req.path !== '/safezone/breach' && req.path !== '/safezone/check') {
        mockUid = req.path.split('/')[2];
      } else if (req.path.startsWith('/locationLogs/')) {
        mockUid = req.path.split('/')[2];
      } else {
        mockUid = req.body.patientId || req.body.userId || req.body.caregiverId;
      }
    }
    req.user = { uid: mockUid };
    return next();
  }

  if (!req.headers.authorization || !req.headers.authorization.startsWith('Bearer ')) {
    return res.status(403).json({ error: 'Unauthorized: Missing or malformed Authorization header' });
  }

  const idToken = req.headers.authorization.split('Bearer ')[1];
  try {
    const decodedIdToken = await admin.auth().verifyIdToken(idToken);
    req.user = decodedIdToken;
    next();
  } catch (error) {
    console.error('Error while verifying Firebase ID token:', error);
    return res.status(403).json({ error: 'Unauthorized: Invalid token' });
  }
};

app.use(validateFirebaseIdToken);

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

    if (req.user.uid !== userId) {
      return res.status(403).json({ error: "Forbidden: Cannot register profile for another user ID" });
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

    if (req.user.uid !== caregiverId) {
      return res.status(403).json({ error: "Forbidden: Only the caregiver can link patient accounts" });
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

// Helper to calculate distance in meters (Haversine formula)
function calculateDistance(lat1, lon1, lat2, lon2) {
  const R = 6371000; // Radius of Earth in meters
  const dLat = (lat2 - lat1) * Math.PI / 180;
  const dLon = (lon2 - lon1) * Math.PI / 180;
  const a = 
    Math.sin(dLat / 2) * Math.sin(dLat / 2) +
    Math.cos(lat1 * Math.PI / 180) * Math.cos(lat2 * Math.PI / 180) * 
    Math.sin(dLon / 2) * Math.sin(dLon / 2);
  const c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
  return R * c;
}

/**
 * POST /safezone/configure
 * Request Body:
 * {
 *   "caregiverId": "string",
 *   "patientId": "string",
 *   "homeLatitude": number,
 *   "homeLongitude": number,
 *   "radius": number,
 *   "activeStatus": boolean
 * }
 */
app.post("/safezone/configure", async (req, res) => {
  try {
    const { caregiverId, patientId, homeLatitude, homeLongitude, radius, activeStatus } = req.body;

    // Validation
    if (!caregiverId || !patientId || homeLatitude === undefined || homeLongitude === undefined || radius === undefined || activeStatus === undefined) {
      return res.status(400).json({ error: "Missing required fields: caregiverId, patientId, homeLatitude, homeLongitude, radius, activeStatus" });
    }

    if (req.user.uid !== caregiverId) {
      return res.status(403).json({ error: "Forbidden: Only the caregiver can configure the safe zone" });
    }

    // Verify Caregiver permission
    const caregiverDoc = await db.collection("users").doc(caregiverId).get();
    if (!caregiverDoc.exists) {
      return res.status(403).json({ error: `Caregiver user with ID ${caregiverId} does not exist` });
    }

    const caregiverData = caregiverDoc.data();
    if (caregiverData.role !== "Caregiver") {
      return res.status(403).json({ error: "Only caregiver users are allowed to configure safe zones" });
    }

    if (caregiverData.linkedPatientId !== patientId) {
      return res.status(403).json({ error: "Caregiver is not linked to this patient" });
    }

    // Validate coordinates
    const lat = Number(homeLatitude);
    const lng = Number(homeLongitude);
    const rad = Number(radius);

    if (isNaN(lat) || lat < -90 || lat > 90) {
      return res.status(400).json({ error: "Latitude must be a valid number between -90 and 90" });
    }
    if (isNaN(lng) || lng < -180 || lng > 180) {
      return res.status(400).json({ error: "Longitude must be a valid number between -180 and 180" });
    }
    if (isNaN(rad) || rad <= 0) {
      return res.status(400).json({ error: "Radius must be a positive number" });
    }

    const safeZoneDocRef = db.collection("safeZones").doc(patientId);
    const safeZoneData = {
      patientId,
      homeLatitude: lat,
      homeLongitude: lng,
      radius: rad,
      activeStatus: Boolean(activeStatus),
      updatedAt: admin.firestore.FieldValue.serverTimestamp()
    };

    await safeZoneDocRef.set(safeZoneData);

    return res.status(200).json({
      message: "Safe zone configured successfully",
      safeZone: safeZoneData
    });
  } catch (error) {
    console.error("Error in /safezone/configure:", error);
    return res.status(500).json({ error: error.message });
  }
});

/**
 * GET /safezone/:patientId
 */
app.get("/safezone/:patientId", async (req, res) => {
  try {
    const { patientId } = req.params;
    if (!patientId) {
      return res.status(400).json({ error: "Missing patientId param" });
    }

    // Auth validation
    const isPatient = (req.user.uid === patientId);
    if (!isPatient) {
      const caregiverDoc = await db.collection("users").doc(req.user.uid).get();
      if (!caregiverDoc.exists || caregiverDoc.data().role !== "Caregiver" || caregiverDoc.data().linkedPatientId !== patientId) {
        return res.status(403).json({ error: "Forbidden: Unauthorized access to safe zone configuration" });
      }
    }

    const safeZoneDoc = await db.collection("safeZones").doc(patientId).get();
    if (!safeZoneDoc.exists) {
      return res.status(404).json({ error: "Safe zone not configured for this patient" });
    }

    return res.status(200).json(safeZoneDoc.data());
  } catch (error) {
    console.error("Error in GET /safezone/:patientId:", error);
    return res.status(500).json({ error: error.message });
  }
});

/**
 * POST /location/update
 * Request Body:
 * {
 *   "patientId": "string",
 *   "latitude": number,
 *   "longitude": number
 * }
 */
app.post("/location/update", async (req, res) => {
  try {
    const { patientId, latitude, longitude } = req.body;

    if (!patientId || latitude === undefined || longitude === undefined) {
      return res.status(400).json({ error: "Missing required fields: patientId, latitude, longitude" });
    }

    if (req.user.uid !== patientId) {
      return res.status(403).json({ error: "Forbidden: Cannot update location for another user" });
    }

    const lat = Number(latitude);
    const lng = Number(longitude);
    if (isNaN(lat) || isNaN(lng)) {
      return res.status(400).json({ error: "Latitude and Longitude must be valid numbers" });
    }

    // 1. Fetch patient profile to get name and linkedCaregiverId
    const patientDoc = await db.collection("users").doc(patientId).get();
    if (!patientDoc.exists) {
      return res.status(404).json({ error: `Patient user with ID ${patientId} does not exist` });
    }
    const patientData = patientDoc.data();
    if (patientData.role !== "Patient") {
      return res.status(400).json({ error: "User is not registered as a Patient" });
    }

    const caregiverId = patientData.linkedCaregiverId;
    const patientName = patientData.name || "Patient";

    // 2. Fetch safe zone configuration
    const safeZoneDoc = await db.collection("safeZones").doc(patientId).get();
    let status = "Inside";
    let breachFlag = false;
    let distance = 0;
    let radius = 0;
    let active = false;

    if (safeZoneDoc.exists) {
      const safeZone = safeZoneDoc.data();
      active = safeZone.activeStatus;
      radius = safeZone.radius;
      if (active) {
        distance = calculateDistance(lat, lng, safeZone.homeLatitude, safeZone.homeLongitude);
        if (distance > radius) {
          status = "Outside";
          breachFlag = true;
        }
      }
    }

    // 3. Fetch previous location log to check status transition (cooldown & re-entry logic)
    const prevLogsSnapshot = await db.collection("locationLogs")
      .where("patientId", "==", patientId)
      .orderBy("timestamp", "desc")
      .limit(1)
      .get();
    
    let previousStatus = null;
    if (!prevLogsSnapshot.empty) {
      previousStatus = prevLogsSnapshot.docs[0].data().status;
    }

    let breachTriggered = false;
    let reentryTriggered = false;

    if (active) {
      if (status === "Outside" && previousStatus !== "Outside") {
        // Cooldown: Transition from Inside/null to Outside -> Trigger Breach Event!
        breachTriggered = true;
      } else if (status === "Inside" && previousStatus === "Outside") {
        // Transition from Outside to Inside -> Trigger Re-entry Event!
        reentryTriggered = true;
      }
    }

    // 4. Handle Breach Events
    if (breachTriggered) {
      // Create alert
      const alertId = `breach_${patientId}`;
      const distanceOutside = distance - radius;
      await db.collection("alerts").doc(alertId).set({
        patientId,
        type: "SafeZoneBreach",
        message: `${patientName} has left the safe zone.`,
        timestamp: admin.firestore.FieldValue.serverTimestamp(),
        resolved: false,
        latitude: lat,
        longitude: lng,
        distanceOutside: Number(distanceOutside.toFixed(1))
      });

      // Notify caregiver
      if (caregiverId) {
        const caregiverDoc = await db.collection("users").doc(caregiverId).get();
        if (caregiverDoc.exists) {
          const caregiverFcmToken = caregiverDoc.data().fcmToken;
          if (caregiverFcmToken) {
            const payload = {
              token: caregiverFcmToken,
              notification: {
                title: "Emergency: Safe Zone Breached!",
                body: `${patientName} has exited the safe zone by ${(distance - radius).toFixed(1)} meters.`,
              },
              android: {
                priority: "high",
                notification: {
                  sound: "emergency_alarm",
                  channelId: "emergency_breach_channel",
                },
              },
              apns: {
                headers: {
                  "apns-priority": "10",
                },
                payload: {
                  aps: {
                    sound: "emergency_alarm.wav",
                  },
                },
              },
              data: {
                patientName,
                breachTime: new Date().toISOString(),
                distanceOutside: String(distanceOutside.toFixed(1)),
                lastCoordinates: `${lat},${lng}`,
                click_action: "OPEN_LOCATION_MAP",
                type: "SafeZoneBreach",
                patientId
              },
            };
            try {
              await admin.messaging().send(payload);
              console.log(`Successfully sent breach notification to caregiver: ${caregiverId}`);
            } catch (err) {
              console.error("Error sending breach notification:", err);
            }
          }
        }
      }
    }

    // 5. Handle Re-entry Events
    if (reentryTriggered) {
      // Resolve alert
      const alertId = `breach_${patientId}`;
      await db.collection("alerts").doc(alertId).set({
        resolved: true,
        resolvedAt: admin.firestore.FieldValue.serverTimestamp()
      }, { merge: true });

      // Notify caregiver of re-entry
      if (caregiverId) {
        const caregiverDoc = await db.collection("users").doc(caregiverId).get();
        if (caregiverDoc.exists) {
          const caregiverFcmToken = caregiverDoc.data().fcmToken;
          if (caregiverFcmToken) {
            const payload = {
              token: caregiverFcmToken,
              notification: {
                title: "Safe Zone Re-entered",
                body: `${patientName} has returned to the safe zone.`,
              },
              android: {
                priority: "high",
                notification: {
                  sound: "default",
                  channelId: "safezone_channel_v1",
                },
              },
              apns: {
                headers: {
                  "apns-priority": "10",
                },
                payload: {
                  aps: {
                    sound: "default",
                  },
                },
              },
              data: {
                patientName,
                reentryTime: new Date().toISOString(),
                lastCoordinates: `${lat},${lng}`,
                click_action: "OPEN_LOCATION_MAP",
                type: "SafeZoneReentry",
                patientId
              },
            };
            try {
              await admin.messaging().send(payload);
              console.log(`Successfully sent re-entry notification to caregiver: ${caregiverId}`);
            } catch (err) {
              console.error("Error sending re-entry notification:", err);
            }
          }
        }
      }
    }

    // 6. Save Location Log
    const logData = {
      patientId,
      timestamp: admin.firestore.FieldValue.serverTimestamp(),
      latitude: lat,
      longitude: lng,
      status,
      breachFlag,
      lastKnownLocation: status === "Inside" ? "Inside safe zone" : `Exited safe zone by ${(distance - radius).toFixed(1)}m`
    };

    await db.collection("locationLogs").doc().set(logData);

    // Also update user's lastKnownLocation info directly in their user profile for quick lookup
    await db.collection("users").doc(patientId).update({
      lastKnownLatitude: lat,
      lastKnownLongitude: lng,
      lastLocationTime: admin.firestore.FieldValue.serverTimestamp(),
      isBreached: breachFlag
    });

    return res.status(200).json({
      message: "Location logged successfully",
      status,
      breachFlag,
      distance: Number(distance.toFixed(1)),
      radius,
      active
    });
  } catch (error) {
    console.error("Error in /location/update:", error);
    return res.status(500).json({ error: error.message });
  }
});

/**
 * GET /locationLogs/:patientId
 * Query Parameters:
 * - limit: number (default 100)
 * - startAfter: timestamp string/number
 */
app.get("/locationLogs/:patientId", async (req, res) => {
  try {
    const { patientId } = req.params;
    if (!patientId) {
      return res.status(400).json({ error: "Missing patientId parameter" });
    }

    // Auth validation
    const isPatient = (req.user.uid === patientId);
    if (!isPatient) {
      const caregiverDoc = await db.collection("users").doc(req.user.uid).get();
      if (!caregiverDoc.exists || caregiverDoc.data().role !== "Caregiver" || caregiverDoc.data().linkedPatientId !== patientId) {
        return res.status(403).json({ error: "Forbidden: Unauthorized access to location history logs" });
      }
    }

    let query = db.collection("locationLogs")
      .where("patientId", "==", patientId)
      .orderBy("timestamp", "desc");

    if (req.query.startAfter) {
      const startAfterVal = Number(req.query.startAfter);
      if (!isNaN(startAfterVal)) {
        // Create a firestore timestamp from milliseconds
        const timestamp = admin.firestore.Timestamp.fromMillis(startAfterVal);
        query = query.startAfter(timestamp);
      }
    }

    const limitVal = parseInt(req.query.limit) || 100;
    query = query.limit(limitVal);

    const snapshot = await query.get();
    const logs = [];
    snapshot.docs.forEach(doc => {
      const data = doc.data();
      logs.push({
        id: doc.id,
        patientId: data.patientId,
        latitude: data.latitude,
        longitude: data.longitude,
        status: data.status,
        breachFlag: data.breachFlag,
        lastKnownLocation: data.lastKnownLocation,
        timestamp: data.timestamp ? data.timestamp.toDate().toISOString() : null
      });
    });

    return res.status(200).json(logs);
  } catch (error) {
    console.error("Error in GET /locationLogs/:patientId:", error);
    return res.status(500).json({ error: error.message });
  }
});

/**
 * POST /safezone/check
 */
app.post("/safezone/check", async (req, res) => {
  try {
    const { patientId, latitude, longitude } = req.body;
    if (!patientId || latitude === undefined || longitude === undefined) {
      return res.status(400).json({ error: "Missing required fields: patientId, latitude, longitude" });
    }

    // Auth validation
    const isPatient = (req.user.uid === patientId);
    if (!isPatient) {
      const caregiverDoc = await db.collection("users").doc(req.user.uid).get();
      if (!caregiverDoc.exists || caregiverDoc.data().role !== "Caregiver" || caregiverDoc.data().linkedPatientId !== patientId) {
        return res.status(403).json({ error: "Forbidden: Unauthorized access to geofence check" });
      }
    }

    const lat = Number(latitude);
    const lng = Number(longitude);

    const safeZoneDoc = await db.collection("safeZones").doc(patientId).get();
    if (!safeZoneDoc.exists) {
      return res.status(200).json({ inside: true, distance: 0, radius: 0, active: false });
    }

    const safeZone = safeZoneDoc.data();
    if (!safeZone.activeStatus) {
      return res.status(200).json({ inside: true, distance: 0, radius: safeZone.radius, active: false });
    }

    const distance = calculateDistance(lat, lng, safeZone.homeLatitude, safeZone.homeLongitude);
    const inside = distance <= safeZone.radius;

    return res.status(200).json({
      inside,
      distance: Number(distance.toFixed(1)),
      radius: safeZone.radius,
      active: true
    });
  } catch (error) {
    console.error("Error in /safezone/check:", error);
    return res.status(500).json({ error: error.message });
  }
});

/**
 * POST /safezone/breach
 * Force triggers breach event workflow (for testing)
 */
app.post("/safezone/breach", async (req, res) => {
  try {
    const { patientId, latitude, longitude } = req.body;
    if (!patientId || latitude === undefined || longitude === undefined) {
      return res.status(400).json({ error: "Missing required fields: patientId, latitude, longitude" });
    }

    // Auth validation
    const isPatient = (req.user.uid === patientId);
    if (!isPatient) {
      const caregiverDoc = await db.collection("users").doc(req.user.uid).get();
      if (!caregiverDoc.exists || caregiverDoc.data().role !== "Caregiver" || caregiverDoc.data().linkedPatientId !== patientId) {
        return res.status(403).json({ error: "Forbidden: Unauthorized access to breach simulation" });
      }
    }

    const lat = Number(latitude);
    const lng = Number(longitude);

    const patientDoc = await db.collection("users").doc(patientId).get();
    if (!patientDoc.exists) {
      return res.status(404).json({ error: `Patient user with ID ${patientId} does not exist` });
    }
    const patientData = patientDoc.data();
    const caregiverId = patientData.linkedCaregiverId;
    const patientName = patientData.name || "Patient";

    // Create breach alert
    const alertId = `breach_${patientId}`;
    await db.collection("alerts").doc(alertId).set({
      patientId,
      type: "SafeZoneBreach",
      message: `${patientName} has left the safe zone.`,
      timestamp: admin.firestore.FieldValue.serverTimestamp(),
      resolved: false,
      latitude: lat,
      longitude: lng,
      distanceOutside: 100 // default mock distance
    });

    if (caregiverId) {
      const caregiverDoc = await db.collection("users").doc(caregiverId).get();
      if (caregiverDoc.exists) {
        const caregiverFcmToken = caregiverDoc.data().fcmToken;
        if (caregiverFcmToken) {
          const payload = {
            token: caregiverFcmToken,
            notification: {
              title: "Emergency: Safe Zone Breached!",
              body: `${patientName} has exited the safe zone by 100.0 meters.`,
            },
            android: {
              priority: "high",
              notification: {
                sound: "emergency_alarm",
                channelId: "emergency_breach_channel",
              },
            },
            apns: {
              headers: {
                "apns-priority": "10",
              },
              payload: {
                aps: {
                  sound: "emergency_alarm.wav",
                },
              },
            },
            data: {
              patientName,
              breachTime: new Date().toISOString(),
              distanceOutside: "100.0",
              lastCoordinates: `${lat},${lng}`,
              click_action: "OPEN_LOCATION_MAP",
              type: "SafeZoneBreach",
              patientId
            },
          };
          await admin.messaging().send(payload);
        }
      }
    }

    // Update patient user's live breach state
    await db.collection("users").doc(patientId).update({
      lastKnownLatitude: lat,
      lastKnownLongitude: lng,
      lastLocationTime: admin.firestore.FieldValue.serverTimestamp(),
      isBreached: true
    });

    // Save a location log
    await db.collection("locationLogs").doc().set({
      patientId,
      timestamp: admin.firestore.FieldValue.serverTimestamp(),
      latitude: lat,
      longitude: lng,
      status: "Outside",
      breachFlag: true,
      lastKnownLocation: "Exited safe zone by 100.0m"
    });

    return res.status(200).json({ message: "Breach triggered successfully" });
  } catch (error) {
    console.error("Error in /safezone/breach:", error);
    return res.status(500).json({ error: error.message });
  }
});

/**
 * POST /unlink-patient
 * Request Body:
 * {
 *   "caregiverId": "string",
 *   "patientId": "string"
 * }
 */
app.post("/unlink-patient", async (req, res) => {
  try {
    const { caregiverId, patientId } = req.body;

    if (!caregiverId || !patientId) {
      return res.status(400).json({ error: "Missing required fields: caregiverId, patientId" });
    }

    // Auth validation: only the caregiver or patient in the link can unlink
    if (req.user.uid !== caregiverId && req.user.uid !== patientId) {
      return res.status(403).json({ error: "Forbidden: You are not authorized to unlink these accounts" });
    }

    const caregiverRef = db.collection("users").doc(caregiverId);
    const patientRef = db.collection("users").doc(patientId);

    await db.runTransaction(async (transaction) => {
      const caregiverDoc = await transaction.get(caregiverRef);
      const patientDoc = await transaction.get(patientRef);

      if (!caregiverDoc.exists || !patientDoc.exists) {
        throw new Error("One or both users do not exist");
      }

      // Perform updates to clear the links
      transaction.update(caregiverRef, { linkedPatientId: null });
      transaction.update(patientRef, { linkedCaregiverId: null });
    });

    return res.status(200).json({
      message: "Caregiver and Patient successfully unlinked",
      caregiverId,
      patientId,
    });
  } catch (error) {
    console.error("Error in /unlink-patient:", error);
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

    const patientId = logData.patientId;



    if (logData.status === "Triggered") {
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
          android: {
            notification: {
              sound: "gentle_reminder",
              channelId: "reminder_channel_v3",
            },
          },
          apns: {
            payload: {
              aps: {
                sound: "gentle_reminder.wav",
              },
            },
          },
          data: {
            logId: snapshot.id,
            reminderId: logData.reminderId || "",
            patientId: logData.patientId || "",
            reminderType: logData.reminderType || "",
            description: logData.description || "",
            instructions: logData.instructions || "",
            snoozeEnabled: String(logData.snoozeEnabled !== false),
            imageUrl: logData.imageUrl || "",
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
          android: {
            notification: {
              sound: "gentle_reminder",
              channelId: "reminder_channel_v3",
            },
          },
          apns: {
            payload: {
              aps: {
                sound: "gentle_reminder.wav",
              },
            },
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

/**
 * Background schedule to run every minute and identify due active reminders,
 * then create the corresponding reminderLogs Triggered document.
 */
exports.checkDueReminders = functions.pubsub
  .schedule("every 1 minutes")
  .onRun(async (context) => {
    const now = new Date();
    try {
      const activeRemindersSnapshot = await db.collection("reminders")
        .where("activeStatus", "==", true)
        .get();

      for (const doc of activeRemindersSnapshot.docs) {
        const reminder = doc.data();
        const reminderId = doc.id;
        const scheduledTime = reminder.scheduledTime.toDate();

        if (scheduledTime <= now) {
          // Check if log already exists for this reminder and scheduledTime
          const existingLogsSnapshot = await db.collection("reminderLogs")
            .where("reminderId", "==", reminderId)
            .where("scheduledTime", "==", reminder.scheduledTime)
            .get();

          if (existingLogsSnapshot.empty) {
            const logId = db.collection("reminderLogs").doc().id;
            const logData = {
              logId: logId,
              reminderId: reminderId,
              patientId: reminder.patientId,
              description: reminder.description,
              instructions: reminder.instructions || "",
              reminderType: reminder.reminderType,
              scheduledTime: reminder.scheduledTime,
              status: "Triggered",
              actionTime: admin.firestore.FieldValue.serverTimestamp(),
              escalationNotified: false,
              snoozeEnabled: reminder.snoozeEnabled !== false,
              imageUrl: reminder.imageUrl || null,
            };
            await db.collection("reminderLogs").doc(logId).set(logData);
            console.log(`Triggered reminder ${reminderId} via backend schedule`);
          }
        }
      }
    } catch (error) {
      console.error("Error checking due reminders:", error);
    }
    return null;
  });

/**
 * Background schedule to run every minute and identify reminderLogs that have
 * exceeded their escalationWaitingDuration (for Triggered) or 5 minutes (for Snoozed).
 */
exports.checkEscalation = functions.pubsub
  .schedule("every 1 minutes")
  .onRun(async (context) => {
    const now = new Date();
    try {
      const pendingLogsSnapshot = await db.collection("reminderLogs")
        .where("status", "in", ["Triggered", "Snoozed"])
        .get();

      for (const doc of pendingLogsSnapshot.docs) {
        const logData = doc.data();
        const logId = doc.id;
        const actionTime = logData.actionTime.toDate();
        const diffMinutes = (now.getTime() - actionTime.getTime()) / 60000;

        if (logData.status === "Triggered") {
          // Fetch the reminder to check escalation waiting duration
          const reminderDoc = await db.collection("reminders").doc(logData.reminderId).get();
          if (reminderDoc.exists) {
            const reminder = reminderDoc.data();
            const waitDuration = reminder.escalationWaitingDuration || 15;
            if (diffMinutes >= waitDuration) {
              await db.collection("reminderLogs").doc(logId).update({
                status: "Missed",
                escalationNotified: true,
                actionTime: admin.firestore.FieldValue.serverTimestamp(),
              });
              console.log(`Escalated log ${logId} (Triggered) to Missed`);
            }
          }
        } else if (logData.status === "Snoozed") {
          // Snooze duration is fixed at 5 minutes
          if (diffMinutes >= 5) {
            await db.collection("reminderLogs").doc(logId).update({
              status: "Missed",
              escalationNotified: true,
              actionTime: admin.firestore.FieldValue.serverTimestamp(),
            });
            console.log(`Escalated log ${logId} (Snoozed) to Missed`);
          }
        }
      }
    } catch (error) {
      console.error("Error checking escalations:", error);
    }
    return null;
  });

/**
 * Triggered when a Firebase Auth user is deleted.
 * Cleans up the user document, their safe zone boundary configurations, 
 * and all related location logs. Revokes links if linked.
 */
exports.onUserDeleted = functions.auth.user().onDelete(async (user) => {
  const userId = user.uid;
  console.log(`User ${userId} deleted. Starting cleanup...`);

  try {
    const userDocRef = db.collection("users").doc(userId);
    const userDoc = await userDocRef.get();

    if (userDoc.exists) {
      const userData = userDoc.data();
      const role = userData.role;

      if (role === "Patient") {
        const linkedCaregiverId = userData.linkedCaregiverId;

        // 1. Delete user profile
        await userDocRef.delete();

        // 2. Delete Safe Zone configuration
        await db.collection("safeZones").doc(userId).delete();

        // 3. Delete location logs in a batch
        const logsSnapshot = await db.collection("locationLogs")
          .where("patientId", "==", userId)
          .get();
        
        if (!logsSnapshot.empty) {
          const batch = db.batch();
          logsSnapshot.docs.forEach((doc) => {
            batch.delete(doc.ref);
          });
          await batch.commit();
          console.log(`Deleted ${logsSnapshot.size} location logs for patient ${userId}`);
        }

        // 4. Update linked caregiver if exists
        if (linkedCaregiverId) {
          await db.collection("users").doc(linkedCaregiverId).update({
            linkedPatientId: null
          });
        }
      } else if (role === "Caregiver") {
        const linkedPatientId = userData.linkedPatientId;

        // 1. Delete user profile
        await userDocRef.delete();

        // 2. Update linked patient if exists
        if (linkedPatientId) {
          await db.collection("users").doc(linkedPatientId).update({
            linkedCaregiverId: null
          });
        }
      }
    } else {
      // Fallback cleanup if user profile was not complete
      await userDocRef.delete();
      await db.collection("safeZones").doc(userId).delete();
      
      const logsSnapshot = await db.collection("locationLogs")
        .where("patientId", "==", userId)
        .get();
      if (!logsSnapshot.empty) {
        const batch = db.batch();
        logsSnapshot.docs.forEach((doc) => {
          batch.delete(doc.ref);
        });
        await batch.commit();
      }
    }
    console.log(`Cleanup completed successfully for user ${userId}`);
  } catch (error) {
    console.error(`Error during user cleanup for ${userId}:`, error);
  }
});
