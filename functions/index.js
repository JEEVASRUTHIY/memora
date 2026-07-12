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
      } else if (req.path.startsWith('/alerts/') && req.path !== '/alerts/create' && req.path !== '/alerts/escalate' && req.path !== '/alerts/resolve') {
        mockUid = req.path.split('/')[2];
      } else if (req.path.startsWith('/behavior/daily-score/') || req.path.startsWith('/behavior/history/')) {
        mockUid = req.path.split('/')[3];
      } else if (req.path.startsWith('/weekly-summary/') && req.path !== '/weekly-summary/generate') {
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

/**
 * POST /alerts/create
 * Body: { patientId, eventType, severity }
 */
app.post("/alerts/create", async (req, res) => {
  try {
    const { patientId, eventType, severity } = req.body;

    if (!patientId || !eventType || !severity) {
      return res.status(400).json({ error: "Missing required fields: patientId, eventType, severity" });
    }

    const allowedTypes = ["Missed Reminder", "Safe Zone Breach", "Behavioral Risk", "SOS", "SOS Trigger"];
    if (!allowedTypes.includes(eventType)) {
      return res.status(400).json({ error: `Invalid eventType. Must be one of: ${allowedTypes.join(", ")}` });
    }

    // Auth validation
    const patientDoc = await db.collection("users").doc(patientId).get();
    if (!patientDoc.exists) {
      return res.status(404).json({ error: `Patient user with ID ${patientId} does not exist` });
    }

    const patientData = patientDoc.data();
    if (patientData.role !== "Patient") {
      return res.status(400).json({ error: "User is not registered as a Patient" });
    }

    const isPatient = (req.user.uid === patientId);
    const isLinkedCaregiver = (patientData.linkedCaregiverId === req.user.uid);

    if (!isPatient && !isLinkedCaregiver) {
      return res.status(403).json({ error: "Forbidden: Unauthorized access to configure alerts for this patient" });
    }

    const alertId = db.collection("alerts").doc().id;
    const alertData = {
      patientId,
      eventType,
      severity,
      alertTimestamp: admin.firestore.FieldValue.serverTimestamp(),
      escalationLevel: "Level 1",
      notificationStatus: "Sent",
      resolved: false
    };

    await db.collection("alerts").doc(alertId).set(alertData);

    // Send Level 1 Notification to patient
    const patientFcmToken = patientData.fcmToken;
    if (patientFcmToken) {
      const payload = {
        token: patientFcmToken,
        notification: {
          title: `Repeat Reminder: ${eventType}`,
          body: `This is a repeat reminder for your safety. Please respond.`,
        },
        android: {
          priority: "high",
          notification: {
            sound: "default",
            channelId: "reminder_channel_v3",
          },
        },
        apns: {
          payload: {
            aps: {
              sound: "default",
            },
          },
        },
        data: {
          type: "RepeatReminder",
          patientId,
          eventType,
          severity,
          alertId,
          escalationLevel: "Level 1",
          click_action: "FLUTTER_NOTIFICATION_CLICK"
        }
      };
      try {
        await admin.messaging().send(payload);
      } catch (err) {
        console.error("Error sending Level 1 patient notification:", err);
      }
    }

    return res.status(201).json({
      message: "Alert created successfully",
      alertId,
      alert: alertData
    });
  } catch (error) {
    console.error("Error in POST /alerts/create:", error);
    return res.status(500).json({ error: error.message });
  }
});

/**
 * GET /alerts/:patientId
 */
app.get("/alerts/:patientId", async (req, res) => {
  try {
    const { patientId } = req.params;
    if (!patientId) {
      return res.status(400).json({ error: "Missing patientId param" });
    }

    const patientDoc = await db.collection("users").doc(patientId).get();
    if (!patientDoc.exists) {
      return res.status(404).json({ error: `Patient user with ID ${patientId} does not exist` });
    }

    const patientData = patientDoc.data();
    const isPatient = (req.user.uid === patientId);
    const isLinkedCaregiver = (patientData.linkedCaregiverId === req.user.uid);

    if (!isPatient && !isLinkedCaregiver) {
      return res.status(403).json({ error: "Forbidden: Unauthorized access to alerts" });
    }

    const snapshot = await db.collection("alerts")
      .where("patientId", "==", patientId)
      .orderBy("alertTimestamp", "desc")
      .get();

    const alerts = [];
    snapshot.docs.forEach(doc => {
      const data = doc.data();
      alerts.push({
        id: doc.id,
        patientId: data.patientId,
        eventType: data.eventType,
        severity: data.severity,
        alertTimestamp: data.alertTimestamp ? (data.alertTimestamp.toDate ? data.alertTimestamp.toDate().toISOString() : new Date(data.alertTimestamp).toISOString()) : null,
        escalationLevel: data.escalationLevel,
        notificationStatus: data.notificationStatus,
        resolved: data.resolved,
        resolvedAt: data.resolvedAt ? (data.resolvedAt.toDate ? data.resolvedAt.toDate().toISOString() : new Date(data.resolvedAt).toISOString()) : null
      });
    });

    return res.status(200).json(alerts);
  } catch (error) {
    console.error("Error in GET /alerts/:patientId:", error);
    return res.status(500).json({ error: error.message });
  }
});

/**
 * POST /alerts/escalate
 * Body: { alertId }
 */
app.post("/alerts/escalate", async (req, res) => {
  try {
    const { alertId } = req.body;
    if (!alertId) {
      return res.status(400).json({ error: "Missing required field: alertId" });
    }

    const alertRef = db.collection("alerts").doc(alertId);
    const alertDoc = await alertRef.get();
    if (!alertDoc.exists) {
      return res.status(404).json({ error: `Alert with ID ${alertId} does not exist` });
    }

    const alertData = alertDoc.data();
    const patientId = alertData.patientId;

    const patientDoc = await db.collection("users").doc(patientId).get();
    if (!patientDoc.exists) {
      return res.status(404).json({ error: `Patient user with ID ${patientId} does not exist` });
    }

    const patientData = patientDoc.data();
    const isPatient = (req.user.uid === patientId);
    const isLinkedCaregiver = (patientData.linkedCaregiverId === req.user.uid);

    if (!isPatient && !isLinkedCaregiver) {
      return res.status(403).json({ error: "Forbidden: Unauthorized access to escalate this alert" });
    }

    if (alertData.resolved) {
      return res.status(400).json({ error: "Cannot escalate a resolved alert" });
    }

    const currentLevel = alertData.escalationLevel || "Level 1";
    let nextLevel = "Level 1";
    if (currentLevel === "Level 1") nextLevel = "Level 2";
    else if (currentLevel === "Level 2") nextLevel = "Level 3";
    else if (currentLevel === "Level 3") nextLevel = "Level 4";
    else if (currentLevel === "Level 4") nextLevel = "Level 4";

    await alertRef.update({
      escalationLevel: nextLevel,
      notificationStatus: "Sent",
      updatedAt: admin.firestore.FieldValue.serverTimestamp()
    });

    const eventType = alertData.eventType || "Safety Alert";
    const patientName = patientData.name || "Patient";

    // Send targeted FCM notifications based on escalation level
    if (nextLevel === "Level 2") {
      // Level 2: Reinforced Reminder to patient
      const patientFcmToken = patientData.fcmToken;
      if (patientFcmToken) {
        const payload = {
          token: patientFcmToken,
          notification: {
            title: `Urgent Reminder: ${eventType}`,
            body: `Please pay immediate attention: Reinforced warning.`,
          },
          android: {
            priority: "high",
            notification: {
              sound: "emergency_alarm",
              channelId: "reminder_channel_v3",
            },
          },
          data: {
            type: "ReinforcedReminder",
            patientId,
            eventType,
            alertId,
            escalationLevel: "Level 2",
            click_action: "FLUTTER_NOTIFICATION_CLICK"
          }
        };
        try {
          await admin.messaging().send(payload);
        } catch (err) {
          console.error("Error sending Level 2 reinforced reminder:", err);
        }
      }
    } else if (nextLevel === "Level 3") {
      // Level 3: Caregiver Notification
      const caregiverId = patientData.linkedCaregiverId;
      if (caregiverId) {
        const caregiverDoc = await db.collection("users").doc(caregiverId).get();
        if (caregiverDoc.exists) {
          const caregiverFcmToken = caregiverDoc.data().fcmToken;
          if (caregiverFcmToken) {
            const payload = {
              token: caregiverFcmToken,
              notification: {
                title: `Caregiver Alert: Escalation Level 3`,
                body: `${patientName} has an unacknowledged alert: ${eventType}.`,
              },
              android: {
                priority: "high",
                notification: {
                  sound: "emergency_alarm",
                  channelId: "emergency_breach_channel",
                },
              },
              data: {
                type: "CaregiverNotification",
                patientId,
                eventType,
                alertId,
                escalationLevel: "Level 3",
                click_action: "FLUTTER_NOTIFICATION_CLICK"
              }
            };
            try {
              await admin.messaging().send(payload);
            } catch (err) {
              console.error("Error sending Level 3 caregiver notification:", err);
            }
          }
        }
      }
    } else if (nextLevel === "Level 4") {
      // Level 4: Emergency Contact Notification (notifying caregiver with high-priority FCM emergency flags)
      const caregiverId = patientData.linkedCaregiverId;
      if (caregiverId) {
        const caregiverDoc = await db.collection("users").doc(caregiverId).get();
        if (caregiverDoc.exists) {
          const caregiverFcmToken = caregiverDoc.data().fcmToken;
          if (caregiverFcmToken) {
            const payload = {
              token: caregiverFcmToken,
              notification: {
                title: `EMERGENCY: Escalation Level 4`,
                body: `CRITICAL: Patient alert unacknowledged. Emergency notification sent.`,
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
                  "apns-priority": "10"
                },
                payload: {
                  aps: {
                    sound: "emergency_alarm.wav"
                  }
                }
              },
              data: {
                type: "EmergencyContactNotification",
                patientId,
                eventType,
                alertId,
                escalationLevel: "Level 4",
                click_action: "FLUTTER_NOTIFICATION_CLICK"
              }
            };
            try {
              await admin.messaging().send(payload);
            } catch (err) {
              console.error("Error sending Level 4 emergency notification:", err);
            }
          }
        }
      }
    }

    return res.status(200).json({
      message: "Alert escalated successfully",
      alertId,
      currentLevel,
      nextLevel
    });
  } catch (error) {
    console.error("Error in POST /alerts/escalate:", error);
    return res.status(500).json({ error: error.message });
  }
});

/**
 * POST /alerts/resolve
 * Body: { alertId }
 */
app.post("/alerts/resolve", async (req, res) => {
  try {
    const { alertId } = req.body;
    if (!alertId) {
      return res.status(400).json({ error: "Missing required field: alertId" });
    }

    const alertRef = db.collection("alerts").doc(alertId);
    const alertDoc = await alertRef.get();
    if (!alertDoc.exists) {
      return res.status(404).json({ error: `Alert with ID ${alertId} does not exist` });
    }

    const alertData = alertDoc.data();
    const patientId = alertData.patientId;

    const patientDoc = await db.collection("users").doc(patientId).get();
    if (!patientDoc.exists) {
      return res.status(404).json({ error: `Patient user with ID ${patientId} does not exist` });
    }

    const patientData = patientDoc.data();
    const isPatient = (req.user.uid === patientId);
    const isLinkedCaregiver = (patientData.linkedCaregiverId === req.user.uid);

    if (!isPatient && !isLinkedCaregiver) {
      return res.status(403).json({ error: "Forbidden: Unauthorized access to resolve this alert" });
    }

    await alertRef.update({
      resolved: true,
      resolvedAt: admin.firestore.FieldValue.serverTimestamp()
    });

    return res.status(200).json({
      message: "Alert successfully resolved",
      alertId
    });
  } catch (error) {
    console.error("Error in POST /alerts/resolve:", error);
    return res.status(500).json({ error: error.message });
  }
});

/**
 * Predicts stability, risk classification, and risk probability based on features.
 * Simulates a Random Forest Classifier decision boundary.
 */
function predictStability(hydration, medication, activity, exits, missed) {
  let score = 0;
  
  // Hydration adherence (0-100) - weight: 0.25
  score += Number(hydration) * 0.25;
  
  // Medication adherence (0-100) - weight: 0.35
  score += Number(medication) * 0.35;
  
  // Activity level (normalized to 100 if number, or maps "high" -> 100, "medium" -> 70, "low" -> 40) - weight: 0.15
  let activityScore = 50;
  if (typeof activity === "number") {
    activityScore = Math.min(100, Math.max(0, activity));
  } else if (typeof activity === "string") {
    const actLower = activity.toLowerCase();
    if (actLower === "high") activityScore = 100;
    else if (actLower === "medium") activityScore = 70;
    else if (actLower === "low") activityScore = 40;
  }
  score += activityScore * 0.15;
  
  // Safe zone exits (exits decrease score, each exit subtracts 15 points, max 45 points off) - weight: 0.20
  const exitPenalty = Math.min(45, Number(exits) * 15);
  score += (45 - exitPenalty) * (20 / 45);
  
  // Missed reminders (each missed reminder subtracts 25 points, max 100 points off) - weight: 0.05
  const missedPenalty = Math.min(100, Number(missed) * 25);
  score += (100 - missedPenalty) * 0.05;
  
  // Ensure score is bounded between 0 and 100
  const finalScore = Math.min(100, Math.max(0, score));
  const riskProbability = 1 - (finalScore / 100);
  const stabilityScore = Number(((1 - riskProbability) * 100).toFixed(1));
  
  let riskClassification = "Stable";
  if (stabilityScore < 50) {
    riskClassification = "High Risk";
  } else if (stabilityScore < 80) {
    riskClassification = "Moderate Risk";
  }
  
  return {
    stabilityScore,
    riskClassification,
    riskProbability
  };
}

/**
 * POST /behavior/daily-score
 * Body: { patientId, date, hydrationAdherencePercentage, medicationAdherencePercentage, activityLevel, safeZoneExits, missedReminders }
 */
app.post("/behavior/daily-score", async (req, res) => {
  try {
    const {
      patientId,
      date,
      hydrationAdherencePercentage,
      medicationAdherencePercentage,
      activityLevel,
      safeZoneExits,
      missedReminders
    } = req.body;

    if (
      !patientId ||
      !date ||
      hydrationAdherencePercentage === undefined ||
      medicationAdherencePercentage === undefined ||
      activityLevel === undefined ||
      safeZoneExits === undefined ||
      missedReminders === undefined
    ) {
      return res.status(400).json({ error: "Missing required fields for daily score computation" });
    }

    // Validate patient existence
    const patientDoc = await db.collection("users").doc(patientId).get();
    if (!patientDoc.exists) {
      return res.status(404).json({ error: `Patient user with ID ${patientId} does not exist` });
    }

    const patientData = patientDoc.data();
    if (patientData.role !== "Patient") {
      return res.status(400).json({ error: "User is not registered as a Patient" });
    }

    // Auth validation
    const isPatient = (req.user.uid === patientId);
    const isLinkedCaregiver = (patientData.linkedCaregiverId === req.user.uid);

    if (!isPatient && !isLinkedCaregiver) {
      return res.status(403).json({ error: "Forbidden: Unauthorized access to post daily score" });
    }

    // Compute stability score
    const { stabilityScore, riskClassification } = predictStability(
      hydrationAdherencePercentage,
      medicationAdherencePercentage,
      activityLevel,
      safeZoneExits,
      missedReminders
    );

    const docId = `${patientId}_${date}`;
    const behaviorData = {
      patientId,
      date,
      hydrationAdherencePercentage: Number(hydrationAdherencePercentage),
      medicationAdherencePercentage: Number(medicationAdherencePercentage),
      activityLevel: typeof activityLevel === "number" ? Number(activityLevel) : activityLevel,
      safeZoneExits: parseInt(safeZoneExits, 10),
      missedReminders: parseInt(missedReminders, 10),
      stabilityScore,
      riskClassification
    };

    await db.collection("dailyBehavior").doc(docId).set(behaviorData);

    // If threshold exceeded (High Risk / stabilityScore < 50), generate alert in the alerts collection
    let triggeredAlertId = null;
    if (stabilityScore < 50) {
      triggeredAlertId = db.collection("alerts").doc().id;
      const alertData = {
        patientId,
        eventType: "Behavioral Risk",
        severity: "High",
        alertTimestamp: admin.firestore.FieldValue.serverTimestamp(),
        escalationLevel: "Level 1",
        notificationStatus: "Sent",
        resolved: false
      };
      await db.collection("alerts").doc(triggeredAlertId).set(alertData);

      // Send caregiver alert notification since it is High Risk
      const caregiverId = patientData.linkedCaregiverId;
      if (caregiverId) {
        const caregiverDoc = await db.collection("users").doc(caregiverId).get();
        if (caregiverDoc.exists) {
          const caregiverFcmToken = caregiverDoc.data().fcmToken;
          if (caregiverFcmToken) {
            const payload = {
              token: caregiverFcmToken,
              notification: {
                title: "High Behavioral Risk Alert",
                body: `Attention: ${patientData.name || "Patient"}'s daily behavioral stability score has dropped to ${stabilityScore} (${riskClassification}).`,
              },
              android: {
                priority: "high",
                notification: {
                  sound: "emergency_alarm",
                  channelId: "emergency_breach_channel",
                },
              },
              data: {
                type: "BehavioralRisk",
                patientId,
                alertId: triggeredAlertId,
                stabilityScore: String(stabilityScore),
                riskClassification,
                click_action: "FLUTTER_NOTIFICATION_CLICK"
              }
            };
            try {
              await admin.messaging().send(payload);
            } catch (err) {
              console.error("Error sending behavioral risk caregiver notification:", err);
            }
          }
        }
      }
    }

    return res.status(201).json({
      message: "Daily behavioral stability score computed successfully",
      stabilityScore,
      riskClassification,
      triggeredAlertId,
      record: behaviorData
    });
  } catch (error) {
    console.error("Error in POST /behavior/daily-score:", error);
    return res.status(500).json({ error: error.message });
  }
});

/**
 * GET /behavior/daily-score/:patientId
 * Query: date (default to today YYYY-MM-DD)
 */
app.get("/behavior/daily-score/:patientId", async (req, res) => {
  try {
    const { patientId } = req.params;
    let { date } = req.query;

    if (!date) {
      // Default to today's date YYYY-MM-DD
      const today = new Date();
      date = today.toISOString().split("T")[0];
    }

    const patientDoc = await db.collection("users").doc(patientId).get();
    if (!patientDoc.exists) {
      return res.status(404).json({ error: `Patient user with ID ${patientId} does not exist` });
    }

    const patientData = patientDoc.data();
    const isPatient = (req.user.uid === patientId);
    const isLinkedCaregiver = (patientData.linkedCaregiverId === req.user.uid);

    if (!isPatient && !isLinkedCaregiver) {
      return res.status(403).json({ error: "Forbidden: Unauthorized access to behavioral score" });
    }

    const docId = `${patientId}_${date}`;
    const behaviorDoc = await db.collection("dailyBehavior").doc(docId).get();
    if (!behaviorDoc.exists) {
      return res.status(404).json({ error: `No behavioral record found for date ${date}` });
    }

    return res.status(200).json(behaviorDoc.data());
  } catch (error) {
    console.error("Error in GET /behavior/daily-score/:patientId:", error);
    return res.status(500).json({ error: error.message });
  }
});

/**
 * GET /behavior/history/:patientId
 * Query: limit (default 30)
 */
app.get("/behavior/history/:patientId", async (req, res) => {
  try {
    const { patientId } = req.params;
    let { limit } = req.query;
    const limitVal = limit ? parseInt(limit, 10) : 30;

    const patientDoc = await db.collection("users").doc(patientId).get();
    if (!patientDoc.exists) {
      return res.status(404).json({ error: `Patient user with ID ${patientId} does not exist` });
    }

    const patientData = patientDoc.data();
    const isPatient = (req.user.uid === patientId);
    const isLinkedCaregiver = (patientData.linkedCaregiverId === req.user.uid);

    if (!isPatient && !isLinkedCaregiver) {
      return res.status(403).json({ error: "Forbidden: Unauthorized access to behavioral history" });
    }

    const snapshot = await db.collection("dailyBehavior")
      .where("patientId", "==", patientId)
      .orderBy("date", "desc")
      .limit(limitVal)
      .get();

    const history = [];
    snapshot.docs.forEach(doc => {
      history.push(doc.data());
    });

    return res.status(200).json(history);
  } catch (error) {
    console.error("Error in GET /behavior/history/:patientId:", error);
    return res.status(500).json({ error: error.message });
  }
});

/**
 * GET /dashboard/:patientId
 */
app.get("/dashboard/:patientId", async (req, res) => {
  try {
    const { patientId } = req.params;

    const patientDoc = await db.collection("users").doc(patientId).get();
    if (!patientDoc.exists) {
      return res.status(404).json({ error: `Patient user with ID ${patientId} does not exist` });
    }

    const patientData = patientDoc.data();
    if (patientData.role !== "Patient") {
      return res.status(400).json({ error: "User is not registered as a Patient" });
    }

    // Auth check
    const isPatient = (req.user.uid === patientId);
    const isLinkedCaregiver = (patientData.linkedCaregiverId === req.user.uid);

    if (!isPatient && !isLinkedCaregiver) {
      return res.status(403).json({ error: "Forbidden: Unauthorized access to dashboard data" });
    }

    // 1. Fetch Safe Zone settings & status
    const safeZoneDoc = await db.collection("safeZones").doc(patientId).get();
    const safeZone = safeZoneDoc.exists ? safeZoneDoc.data() : null;

    const locationLogsSnapshot = await db.collection("locationLogs")
      .where("patientId", "==", patientId)
      .orderBy("timestamp", "desc")
      .limit(1)
      .get();
    const latestLocationLog = !locationLogsSnapshot.empty ? locationLogsSnapshot.docs[0].data() : null;

    // 2. Fetch latest Daily Behavior score
    const behaviorSnapshot = await db.collection("dailyBehavior")
      .where("patientId", "==", patientId)
      .orderBy("date", "desc")
      .limit(1)
      .get();
    const latestBehavior = !behaviorSnapshot.empty ? behaviorSnapshot.docs[0].data() : null;

    // 3. Fetch Active Alerts (resolved == false)
    const activeAlertsSnapshot = await db.collection("alerts")
      .where("patientId", "==", patientId)
      .where("resolved", "==", false)
      .orderBy("alertTimestamp", "desc")
      .get();
    const activeAlertsList = activeAlertsSnapshot.docs.map(doc => {
      const d = doc.data();
      return {
        id: doc.id,
        ...d,
        alertTimestamp: d.alertTimestamp ? (d.alertTimestamp.toDate ? d.alertTimestamp.toDate().toISOString() : new Date(d.alertTimestamp).toISOString()) : null
      };
    });

    // 4. Fetch Historical Alerts (resolved == true)
    const historicalAlertsSnapshot = await db.collection("alerts")
      .where("patientId", "==", patientId)
      .where("resolved", "==", true)
      .orderBy("alertTimestamp", "desc")
      .limit(5)
      .get();
    const historicalAlertsList = historicalAlertsSnapshot.docs.map(doc => {
      const d = doc.data();
      return {
        id: doc.id,
        ...d,
        alertTimestamp: d.alertTimestamp ? (d.alertTimestamp.toDate ? d.alertTimestamp.toDate().toISOString() : new Date(d.alertTimestamp).toISOString()) : null,
        resolvedAt: d.resolvedAt ? (d.resolvedAt.toDate ? d.resolvedAt.toDate().toISOString() : new Date(d.resolvedAt).toISOString()) : null
      };
    });

    // 5. Fetch Recent Reminder Activity (limit 5)
    const reminderLogsSnapshot = await db.collection("reminderLogs")
      .where("patientId", "==", patientId)
      .orderBy("scheduledTime", "desc")
      .limit(5)
      .get();
    const recentRemindersList = reminderLogsSnapshot.docs.map(doc => {
      const d = doc.data();
      return {
        id: doc.id,
        ...d,
        scheduledTime: d.scheduledTime ? (d.scheduledTime.toDate ? d.scheduledTime.toDate().toISOString() : new Date(d.scheduledTime).toISOString()) : null,
        actionTime: d.actionTime ? (d.actionTime.toDate ? d.actionTime.toDate().toISOString() : new Date(d.actionTime).toISOString()) : null
      };
    });

    // 6. Fetch Latest Weekly Summary
    const summariesSnapshot = await db.collection("weeklySummaries")
      .where("patientId", "==", patientId)
      .orderBy("timestamp", "desc")
      .limit(1)
      .get();
    const latestSummary = !summariesSnapshot.empty ? summariesSnapshot.docs[0].data() : null;

    // Response compilation
    return res.status(200).json({
      medicationAdherence: latestBehavior ? latestBehavior.medicationAdherencePercentage : 100,
      hydrationAdherence: latestBehavior ? latestBehavior.hydrationAdherencePercentage : 100,
      safeZoneStatus: {
        configured: !!safeZone,
        active: safeZone ? safeZone.activeStatus : false,
        isBreached: latestLocationLog ? (latestLocationLog.status === "Outside") : false,
        latestLocation: latestLocationLog ? {
          latitude: latestLocationLog.latitude,
          longitude: latestLocationLog.longitude,
          timestamp: latestLocationLog.timestamp ? (latestLocationLog.timestamp.toDate ? latestLocationLog.timestamp.toDate().toISOString() : new Date(latestLocationLog.timestamp).toISOString()) : null
        } : null
      },
      behavioralStability: {
        score: latestBehavior ? latestBehavior.stabilityScore : 100,
        classification: latestBehavior ? latestBehavior.riskClassification : "Stable"
      },
      activeAlerts: activeAlertsList,
      historicalAlerts: historicalAlertsList,
      recentReminderActivity: recentRemindersList,
      weeklyInsightsPreview: latestSummary ? latestSummary.insights : "No insights available yet."
    });
  } catch (error) {
    console.error("Error in GET /dashboard/:patientId:", error);
    return res.status(500).json({ error: error.message });
  }
});

/**
 * GET /dashboard/adherence/:patientId
 */
app.get("/dashboard/adherence/:patientId", async (req, res) => {
  try {
    const { patientId } = req.params;

    const patientDoc = await db.collection("users").doc(patientId).get();
    if (!patientDoc.exists) {
      return res.status(404).json({ error: `Patient user with ID ${patientId} does not exist` });
    }

    const patientData = patientDoc.data();
    if (patientData.role !== "Patient") {
      return res.status(400).json({ error: "User is not registered as a Patient" });
    }

    // Auth check
    const isPatient = (req.user.uid === patientId);
    const isLinkedCaregiver = (patientData.linkedCaregiverId === req.user.uid);

    if (!isPatient && !isLinkedCaregiver) {
      return res.status(403).json({ error: "Forbidden: Unauthorized access to adherence data" });
    }

    // Fetch the last 7 daily behaviors to average adherence rates
    const behaviorSnapshot = await db.collection("dailyBehavior")
      .where("patientId", "==", patientId)
      .orderBy("date", "desc")
      .limit(7)
      .get();

    let totalMed = 0;
    let totalHyd = 0;
    let totalStability = 0;
    const count = behaviorSnapshot.docs.length;

    behaviorSnapshot.docs.forEach(doc => {
      const data = doc.data();
      totalMed += data.medicationAdherencePercentage || 0;
      totalHyd += data.hydrationAdherencePercentage || 0;
      totalStability += data.stabilityScore || 0;
    });

    const medicationAdherenceAverage = count > 0 ? Number((totalMed / count).toFixed(1)) : 100;
    const hydrationAdherenceAverage = count > 0 ? Number((totalHyd / count).toFixed(1)) : 100;
    const stabilityScoreAverage = count > 0 ? Number((totalStability / count).toFixed(1)) : 100;

    // Fetch status counts of reminder logs in the last 7 days
    const sevenDaysAgo = new Date();
    sevenDaysAgo.setDate(sevenDaysAgo.getDate() - 7);

    const reminderLogsSnapshot = await db.collection("reminderLogs")
      .where("patientId", "==", patientId)
      .where("scheduledTime", ">=", sevenDaysAgo)
      .get();

    const statusCounts = {
      Completed: 0,
      Missed: 0,
      Snoozed: 0,
      Triggered: 0,
      Confirmed: 0
    };

    reminderLogsSnapshot.docs.forEach(doc => {
      const data = doc.data();
      if (statusCounts[data.status] !== undefined) {
        statusCounts[data.status]++;
      }
    });

    return res.status(200).json({
      medicationAdherenceAverage,
      hydrationAdherenceAverage,
      stabilityScoreAverage,
      statusCounts
    });
  } catch (error) {
    console.error("Error in GET /dashboard/adherence/:patientId:", error);
    return res.status(500).json({ error: error.message });
  }
});

/**
 * GET /dashboard/trends/:patientId
 */
app.get("/dashboard/trends/:patientId", async (req, res) => {
  try {
    const { patientId } = req.params;

    const patientDoc = await db.collection("users").doc(patientId).get();
    if (!patientDoc.exists) {
      return res.status(404).json({ error: `Patient user with ID ${patientId} does not exist` });
    }

    const patientData = patientDoc.data();
    if (patientData.role !== "Patient") {
      return res.status(400).json({ error: "User is not registered as a Patient" });
    }

    // Auth check
    const isPatient = (req.user.uid === patientId);
    const isLinkedCaregiver = (patientData.linkedCaregiverId === req.user.uid);

    if (!isPatient && !isLinkedCaregiver) {
      return res.status(403).json({ error: "Forbidden: Unauthorized access to trends data" });
    }

    // Fetch the last 7 daily behavior logs (trends)
    const behaviorSnapshot = await db.collection("dailyBehavior")
      .where("patientId", "==", patientId)
      .orderBy("date", "desc")
      .limit(7)
      .get();
    const trends = behaviorSnapshot.docs.map(doc => doc.data()).reverse(); // Older first

    // Fetch the latest weekly summary
    const summariesSnapshot = await db.collection("weeklySummaries")
      .where("patientId", "==", patientId)
      .orderBy("timestamp", "desc")
      .limit(1)
      .get();
    const latestSummary = !summariesSnapshot.empty ? summariesSnapshot.docs[0].data() : null;

    return res.status(200).json({
      trends,
      weeklyInsights: latestSummary ? latestSummary.insights : "No weekly summary available yet."
    });
  } catch (error) {
    console.error("Error in GET /dashboard/trends/:patientId:", error);
    return res.status(500).json({ error: error.message });
  }
});

/**
 * Predicts and formats weekly insights dynamically following non-clinical safety rules.
 * Never gives a diagnosis or treatment advice.
 */
function generateWeeklyInsights(metrics, retrievedGuidance) {
  const cards = [];
  const summaryParts = [];
  const suggestions = [];

  // Stability overall comments (non-clinical description)
  if (metrics.averageStabilityScore >= 80) {
    summaryParts.push("Overall behavioral patterns were consistent and stable throughout the week.");
  } else if (metrics.averageStabilityScore >= 50) {
    summaryParts.push("Some mild variations in daily routines were observed, showing moderate stability.");
  } else {
    summaryParts.push("Behavioral stability score indicates noticeable routine variances this week. Supportive engagement is encouraged.");
  }

  // Hydration comments
  if (metrics.hydrationAdherencePercentage >= 80) {
    summaryParts.push("Hydration levels remained consistent with reminder schedules.");
  } else {
    summaryParts.push("A slight decline in hydration reminder adherence was noted.");
  }

  // Medication comments
  if (metrics.medicationAdherencePercentage >= 80) {
    summaryParts.push("Medication reminder adherence was strong.");
  } else {
    summaryParts.push("Medication adherence showed some missed logs.");
  }

  // Map retrieved guidance snippets to cards and supportive suggestions
  retrievedGuidance.forEach(guidance => {
    cards.push({
      title: `${guidance.topic} Insight`,
      description: guidance.guidanceText,
      category: guidance.safetyCategory
    });
    suggestions.push(guidance.guidanceText);
  });

  // Default fallback card if none matched
  if (cards.length === 0) {
    cards.push({
      title: "Routine Consistency",
      description: "No significant declines in routine adherence were detected this week. Encourage patient to keep setting reminder logs.",
      category: "Routine support"
    });
    suggestions.push("Encourage patient to keep setting reminder logs.");
  }

  const weeklySummaryText = summaryParts.join(" ");

  return {
    weeklySummaryText,
    insightCards: cards,
    supportiveSuggestions: suggestions
  };
}

/**
 * POST /weekly-summary/generate
 * Body: { patientId, weekId }
 */
app.post("/weekly-summary/generate", async (req, res) => {
  try {
    const { patientId, weekId } = req.body;

    if (!patientId || !weekId) {
      return res.status(400).json({ error: "Missing required fields: patientId, weekId" });
    }

    const patientDoc = await db.collection("users").doc(patientId).get();
    if (!patientDoc.exists) {
      return res.status(404).json({ error: `Patient user with ID ${patientId} does not exist` });
    }

    const patientData = patientDoc.data();
    if (patientData.role !== "Patient") {
      return res.status(400).json({ error: "User is not registered as a Patient" });
    }

    // Auth check
    const isPatient = (req.user.uid === patientId);
    const isLinkedCaregiver = (patientData.linkedCaregiverId === req.user.uid);

    if (!isPatient && !isLinkedCaregiver) {
      return res.status(403).json({ error: "Forbidden: Unauthorized access to weekly summary generation" });
    }

    // 1. Aggregate daily behavior for the last 7 logs
    const behaviorSnapshot = await db.collection("dailyBehavior")
      .where("patientId", "==", patientId)
      .orderBy("date", "desc")
      .limit(7)
      .get();

    if (behaviorSnapshot.empty) {
      return res.status(400).json({ error: "Cannot generate weekly summary: no daily behavioral data found for the patient" });
    }

    let totalMed = 0;
    let totalHyd = 0;
    let totalStability = 0;
    let totalExits = 0;
    let totalMissed = 0;
    const trends = behaviorSnapshot.docs.map(doc => doc.data());
    const count = trends.length;

    trends.forEach(data => {
      totalMed += data.medicationAdherencePercentage || 0;
      totalHyd += data.hydrationAdherencePercentage || 0;
      totalStability += data.stabilityScore || 0;
      totalExits += data.safeZoneExits || 0;
      totalMissed += data.missedReminders || 0;
    });

    const averageStabilityScore = Number((totalStability / count).toFixed(1));
    const hydrationAdherencePercentage = Number((totalHyd / count).toFixed(1));
    const medicationAdherencePercentage = Number((totalMed / count).toFixed(1));
    const safeZoneExits = totalExits;

    // Detect Stability Trend: newest score compared to oldest score in trends array
    const latestScore = trends[0].stabilityScore || 0;
    const oldestScore = trends[count - 1].stabilityScore || 0;
    const diff = latestScore - oldestScore;
    let stabilityTrend = "Stable";
    if (diff > 5) stabilityTrend = "Improving";
    else if (diff < -5) stabilityTrend = "Declining";

    // 2. Fetch alert count in the last 7 days
    const sevenDaysAgo = new Date();
    sevenDaysAgo.setDate(sevenDaysAgo.getDate() - 7);

    const alertsSnapshot = await db.collection("alerts")
      .where("patientId", "==", patientId)
      .where("alertTimestamp", ">=", sevenDaysAgo)
      .get();
    const alertCount = alertsSnapshot.docs.length;

    // 3. RAG Retrieval from guidanceKnowledge
    const triggers = [];
    if (medicationAdherencePercentage < 80 || stabilityTrend === "Declining") {
      triggers.push("Medication Decline");
    }
    if (hydrationAdherencePercentage < 80 || stabilityTrend === "Declining") {
      triggers.push("Hydration Decline");
    }
    if (alertCount > 3) {
      triggers.push("Alert Frequency");
    }
    if (safeZoneExits > 1) {
      triggers.push("Safe Zone Violations");
    }
    if (averageStabilityScore < 70) {
      triggers.push("Stability Drop");
    }

    // Seed guidanceKnowledge if empty
    const guidanceKnowledgeCheck = await db.collection("guidanceKnowledge").get();
    if (guidanceKnowledgeCheck.empty) {
      const seedData = [
        { topic: "Medication Decline", triggerCondition: "Medication adherence drops below 80% or shows a declining trend.", guidanceText: "Ensure medication reminders are set at optimal active times. Consider using a physical pill organizer to complement digital reminders.", safetyCategory: "Routine support" },
        { topic: "Hydration Decline", triggerCondition: "Hydration adherence drops below 80% or shows a declining trend.", guidanceText: "Encourage hydration by placing water bottles in high-visibility areas around the living space. Offer flavored water or herbal teas.", safetyCategory: "Well-being support" },
        { topic: "Alert Frequency", triggerCondition: "Alert count is high (above 3 alerts per week).", guidanceText: "Frequent safety alerts may indicate a need to adjust daily schedules or reminder timings. Review active reminder descriptions for clarity.", safetyCategory: "Safety monitoring" },
        { topic: "Safe Zone Violations", triggerCondition: "Safe zone breach alert triggered more than once.", guidanceText: "Review safe zone boundaries to ensure they encompass typical daily routes. Consider walking the boundary together to verify comfort levels.", safetyCategory: "Geofence monitoring" },
        { topic: "Stability Drop", triggerCondition: "Overall stability score falls below 70% or shows a significant drop.", guidanceText: "Provide gentle routine consistency to help restore comfort. Focus on regular hydration and medication timings.", safetyCategory: "Stability monitoring" }
      ];
      const seedBatch = db.batch();
      seedData.forEach(item => {
        const ref = db.collection("guidanceKnowledge").doc();
        seedBatch.set(ref, item);
      });
      await seedBatch.commit();
    }

    let retrievedGuidance = [];
    if (triggers.length > 0) {
      const guidanceSnapshot = await db.collection("guidanceKnowledge")
        .where("topic", "in", triggers)
        .get();
      retrievedGuidance = guidanceSnapshot.docs.map(doc => doc.data());
    }

    // 4. Generate Weekly Summary & Cards (Simulating RAG prompt processing)
    const { weeklySummaryText, insightCards } = generateWeeklyInsights(
      {
        averageStabilityScore,
        hydrationAdherencePercentage,
        medicationAdherencePercentage,
        alertCount,
        safeZoneExits
      },
      retrievedGuidance
    );

    // 5. Retention: keep latest 4 summaries, delete older
    const summariesSnapshot = await db.collection("weeklySummaries")
      .where("patientId", "==", patientId)
      .orderBy("timestamp", "desc")
      .get();

    if (summariesSnapshot.docs.length >= 4) {
      const deleteBatch = db.batch();
      // Keep only 3 newest, so when we add the 4th, it stays at exactly 4 docs
      const docsToDelete = summariesSnapshot.docs.slice(3);
      docsToDelete.forEach(doc => {
        deleteBatch.delete(doc.ref);
      });
      await deleteBatch.commit();
    }

    // Save weekly summary
    const summaryId = `${patientId}_${weekId}`;
    const summaryData = {
      patientId,
      weekId,
      averageStabilityScore,
      hydrationAdherencePercentage,
      medicationAdherencePercentage,
      alertCount,
      safeZoneExits,
      weeklySummaryText,
      insightCards,
      timestamp: admin.firestore.FieldValue.serverTimestamp()
    };

    await db.collection("weeklySummaries").doc(summaryId).set(summaryData);

    return res.status(201).json({
      message: "Weekly summary generated successfully",
      summaryId,
      summary: summaryData
    });
  } catch (error) {
    console.error("Error in POST /weekly-summary/generate:", error);
    return res.status(500).json({ error: error.message });
  }
});

/**
 * GET /weekly-summary/:patientId
 */
app.get("/weekly-summary/:patientId", async (req, res) => {
  try {
    const { patientId } = req.params;

    const patientDoc = await db.collection("users").doc(patientId).get();
    if (!patientDoc.exists) {
      return res.status(404).json({ error: `Patient user with ID ${patientId} does not exist` });
    }

    const patientData = patientDoc.data();
    const isPatient = (req.user.uid === patientId);
    const isLinkedCaregiver = (patientData.linkedCaregiverId === req.user.uid);

    if (!isPatient && !isLinkedCaregiver) {
      return res.status(403).json({ error: "Forbidden: Unauthorized access to weekly summaries" });
    }

    const snapshot = await db.collection("weeklySummaries")
      .where("patientId", "==", patientId)
      .orderBy("timestamp", "desc")
      .get();

    const summaries = snapshot.docs.map(doc => {
      const d = doc.data();
      return {
        id: doc.id,
        ...d,
        timestamp: d.timestamp ? (d.timestamp.toDate ? d.timestamp.toDate().toISOString() : new Date(d.timestamp).toISOString()) : null
      };
    });

    return res.status(200).json(summaries);
  } catch (error) {
    console.error("Error in GET /weekly-summary/:patientId:", error);
    return res.status(500).json({ error: error.message });
  }
});

/**
 * POST /sos/trigger
 * Body: { patientId }
 */
app.post("/sos/trigger", async (req, res) => {
  try {
    const { patientId } = req.body;
    if (!patientId) {
      return res.status(400).json({ error: "Missing required field: patientId" });
    }

    const patientDoc = await db.collection("users").doc(patientId).get();
    if (!patientDoc.exists) {
      return res.status(404).json({ error: `Patient user with ID ${patientId} does not exist` });
    }

    const patientData = patientDoc.data();
    if (patientData.role !== "Patient") {
      return res.status(400).json({ error: "User is not registered as a Patient" });
    }

    // Auth validation
    const isPatient = (req.user.uid === patientId);
    const isLinkedCaregiver = (patientData.linkedCaregiverId === req.user.uid);
    if (!isPatient && !isLinkedCaregiver) {
      return res.status(403).json({ error: "Forbidden: Unauthorized to trigger SOS for this patient" });
    }

    const alertId = db.collection("alerts").doc().id;
    const alertData = {
      patientId,
      eventType: "SOS Trigger",
      severity: "HIGH",
      alertTimestamp: admin.firestore.FieldValue.serverTimestamp(),
      escalationLevel: "Level 4",
      notificationStatus: "Sent",
      resolved: false
    };

    await db.collection("alerts").doc(alertId).set(alertData);

    const patientName = patientData.name || "Patient";

    // 1. Notify Caregiver via FCM
    const caregiverId = patientData.linkedCaregiverId;
    if (caregiverId) {
      const caregiverDoc = await db.collection("users").doc(caregiverId).get();
      if (caregiverDoc.exists) {
        const caregiverFcmToken = caregiverDoc.data().fcmToken;
        if (caregiverFcmToken) {
          const caregiverPayload = {
            token: caregiverFcmToken,
            notification: {
              title: "SOS Emergency Alert!",
              body: `CRITICAL: ${patientName} has triggered an SOS emergency alert. Please respond immediately.`,
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
                "apns-priority": "10"
              },
              payload: {
                aps: {
                  sound: "emergency_alarm.wav"
                }
              }
            },
            data: {
              type: "SOSTrigger",
              patientId,
              alertId,
              escalationLevel: "Level 4",
              click_action: "FLUTTER_NOTIFICATION_CLICK"
            }
          };
          try {
            await admin.messaging().send(caregiverPayload);
          } catch (err) {
            console.error("Error sending SOS notification to caregiver:", err);
          }
        }
      }
    }

    // 2. Notify Emergency Contacts via FCM
    if (patientData.emergencyContacts && Array.isArray(patientData.emergencyContacts)) {
      for (const contact of patientData.emergencyContacts) {
        if (contact.fcmToken) {
          const contactPayload = {
            token: contact.fcmToken,
            notification: {
              title: `SOS Emergency: ${patientName}`,
              body: `CRITICAL: ${patientName} has triggered an emergency alert. Please contact them immediately.`,
            },
            android: {
              priority: "high",
              notification: {
                sound: "emergency_alarm",
                channelId: "emergency_breach_channel",
              },
            },
            data: {
              type: "SOSTrigger",
              patientId,
              alertId,
              escalationLevel: "Level 4",
              click_action: "FLUTTER_NOTIFICATION_CLICK"
            }
          };
          try {
            await admin.messaging().send(contactPayload);
          } catch (err) {
            console.error(`Error sending SOS notification to contact: ${contact.name || "Unknown"}`, err);
          }
        }
      }
    }

    return res.status(201).json({
      message: "SOS alert triggered successfully",
      alertId,
      alert: alertData
    });
  } catch (error) {
    console.error("Error in POST /sos/trigger:", error);
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
