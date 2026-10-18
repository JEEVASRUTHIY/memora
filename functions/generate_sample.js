const admin = require("firebase-admin");

// Initialize firebase-admin. It will connect to the active project.
admin.initializeApp({
  projectId: "memora-3b359"
});

const db = admin.firestore();

async function run() {
  try {
    console.log("Searching for a patient in the database...");
    const usersSnapshot = await db.collection("users").where("role", "==", "Patient").limit(1).get();
    
    let patientId;
    if (usersSnapshot.empty) {
      console.log("No patient found. Creating a sample patient 'sample_patient'...");
      patientId = "sample_patient";
      await db.collection("users").doc(patientId).set({
        userId: patientId,
        name: "Jane Doe (Sample)",
        role: "Patient",
        contactDetails: "jane.doe@example.com",
        linkedCaregiverId: "sample_caregiver"
      });
      await db.collection("users").doc("sample_caregiver").set({
        userId: "sample_caregiver",
        name: "John Doe (Sample)",
        role: "Caregiver",
        contactDetails: "john.doe@example.com",
        linkedPatientId: patientId
      });
    } else {
      patientId = usersSnapshot.docs[0].id;
      console.log(`Found existing patient: ${patientId}`);
    }

    const todayStr = new Date().toISOString().split("T")[0];
    
    // 1. Generate Daily Behavior record
    console.log(`Generating daily behavior record for patient ${patientId} on date ${todayStr}...`);
    const behaviorData = {
      patientId,
      date: todayStr,
      hydrationAdherencePercentage: 85.0,
      medicationAdherencePercentage: 90.0,
      activityLevel: "Medium",
      safeZoneExits: 0,
      missedReminders: 0,
      stabilityScore: 88.0,
      riskClassification: "Stable",
      timestamp: admin.firestore.FieldValue.serverTimestamp()
    };
    await db.collection("dailyBehavior").doc(`${patientId}_${todayStr}`).set(behaviorData);
    console.log("Successfully created dailyBehavior record.");

    // 2. Generate Weekly Summary record
    const weekId = "2026-W28";
    console.log(`Generating weekly summary record for patient ${patientId} and week ${weekId}...`);
    const weeklyData = {
      patientId,
      weekId,
      averageStabilityScore: 85.0,
      hydrationAdherencePercentage: 80.0,
      medicationAdherencePercentage: 90.0,
      alertCount: 1,
      safeZoneExits: 0,
      weeklySummaryText: "Overall stability remained high. Hydration and medication reminder logs show strong adherence with minor routine variances.",
      insightCards: [
        {
          title: "Medication Adherence Insight",
          description: "Patient responded to 90% of medication reminder logs on time. Suggest keeping current schedules.",
          category: "Routine support"
        },
        {
          title: "Hydration Adherence Insight",
          description: "Hydration levels are stable. Minor decline detected on Wednesday; encourage water intake in high-visibility areas.",
          category: "Well-being support"
        }
      ],
      timestamp: admin.firestore.FieldValue.serverTimestamp()
    };
    await db.collection("weeklySummaries").doc(`${patientId}_${weekId}`).set(weeklyData);
    console.log("Successfully created weeklySummaries record.");

  } catch (error) {
    console.error("Error generating sample data:", error);
  }
}

run();
