const chai = require("chai");
const expect = chai.expect;
const request = require("supertest");

// 1. Setup Firestore Mock
const store = {};
const dbMock = {
  collection: (colName) => ({
    doc: (id) => {
      const docRef = {
        set: async (data) => {
          store[id] = { ...data };
          return { writeTime: new Date() };
        },
        get: async () => {
          const data = store[id];
          return {
            exists: !!data,
            data: () => data,
          };
        },
        update: async (data) => {
          if (!store[id]) throw new Error("Doc does not exist");
          store[id] = { ...store[id], ...data };
          return { writeTime: new Date() };
        }
      };
      return docRef;
    }
  }),
  runTransaction: async (handler) => {
    const transaction = {
      get: async (docRef) => docRef.get(),
      update: (docRef, data) => {
        // Directly update the document in mock store
        return docRef.update(data);
      }
    };
    return handler(transaction);
  }
};

const adminMock = {
  initializeApp: () => {},
  firestore: Object.assign(() => dbMock, {
    FieldValue: {
      serverTimestamp: () => "mock-timestamp"
    }
  }),
  messaging: () => ({
    send: async (msg) => {
      adminMock.lastSentMessage = msg;
      return "mock-message-id";
    }
  }),
  lastSentMessage: null
};

// Cache the mock so require('firebase-admin') returns adminMock
require.cache[require.resolve("firebase-admin")] = {
  id: require.resolve("firebase-admin"),
  filename: require.resolve("firebase-admin"),
  loaded: true,
  exports: adminMock
};

// Mock firebase-functions
const functionsMock = {
  https: {
    onRequest: (handler) => handler
  },
  firestore: {
    document: (path) => ({
      onCreate: (handler) => handler,
      onUpdate: (handler) => handler
    })
  }
};
require.cache[require.resolve("firebase-functions")] = {
  id: require.resolve("firebase-functions"),
  filename: require.resolve("firebase-functions"),
  loaded: true,
  exports: functionsMock
};

// Now import the app from index.js
const { users } = require("./index.js");

describe("Cloud Functions API Tests", () => {
  beforeEach(() => {
    // Clear mock store before each test
    for (const key in store) {
      delete store[key];
    }
  });

  describe("POST /register", () => {
    it("should successfully register a patient", async () => {
      const res = await request(users)
        .post("/register")
        .send({
          userId: "patient123",
          role: "Patient",
          name: "John Doe",
          contactDetails: "john@example.com"
        });

      expect(res.status).to.equal(201);
      expect(res.body.message).to.equal("User registered successfully");
      expect(res.body.user.userId).to.equal("patient123");
      expect(res.body.user.role).to.equal("Patient");
      expect(store["patient123"]).to.exist;
      expect(store["patient123"].name).to.equal("John Doe");
    });

    it("should fail validation if role is invalid", async () => {
      const res = await request(users)
        .post("/register")
        .send({
          userId: "user123",
          role: "Doctor",
          name: "Dr. Smith",
          contactDetails: "smith@example.com"
        });

      expect(res.status).to.equal(400);
      expect(res.body.error).to.equal("Role must be either 'Patient' or 'Caregiver'");
    });

    it("should fail validation if fields are missing", async () => {
      const res = await request(users)
        .post("/register")
        .send({
          userId: "user123",
          role: "Patient"
        });

      expect(res.status).to.equal(400);
      expect(res.body.error).to.contain("Missing required fields");
    });
  });

  describe("POST /link-patient", () => {
    beforeEach(async () => {
      // Setup mock data for links
      store["caregiver1"] = {
        userId: "caregiver1",
        role: "Caregiver",
        name: "Jane Caregiver",
        contactDetails: "jane@example.com",
        linkedPatientId: null,
        linkedCaregiverId: null
      };

      store["patient1"] = {
        userId: "patient1",
        role: "Patient",
        name: "Jimmy Patient",
        contactDetails: "jimmy@example.com",
        linkedPatientId: null,
        linkedCaregiverId: null
      };
    });

    it("should successfully link caregiver and patient", async () => {
      const res = await request(users)
        .post("/link-patient")
        .send({
          caregiverId: "caregiver1",
          patientId: "patient1"
        });

      expect(res.status).to.equal(200);
      expect(res.body.message).to.equal("Caregiver and Patient successfully linked");
      expect(store["caregiver1"].linkedPatientId).to.equal("patient1");
      expect(store["patient1"].linkedCaregiverId).to.equal("caregiver1");
    });

    it("should fail if caregiver does not exist", async () => {
      const res = await request(users)
        .post("/link-patient")
        .send({
          caregiverId: "nonexistent",
          patientId: "patient1"
        });

      expect(res.status).to.equal(500);
      expect(res.body.error).to.contain("does not exist");
    });

    it("should fail if caregiver user has incorrect role", async () => {
      // Modify caregiver role to Patient
      store["caregiver1"].role = "Patient";

      const res = await request(users)
        .post("/link-patient")
        .send({
          caregiverId: "caregiver1",
          patientId: "patient1"
        });

      expect(res.status).to.equal(500);
      expect(res.body.error).to.contain("not registered as a Caregiver");
    });

    it("should fail if caregiver user is already linked to another patient", async () => {
      // Setup already linked caregiver
      store["caregiver1"].linkedPatientId = "anotherPatient";

      const res = await request(users)
        .post("/link-patient")
        .send({
          caregiverId: "caregiver1",
          patientId: "patient1"
        });

      expect(res.status).to.equal(500);
      expect(res.body.error).to.contain("already linked to another patient");
    });

    it("should fail if patient user is already linked to another caregiver", async () => {
      // Setup already linked patient
      store["patient1"].linkedCaregiverId = "anotherCaregiver";

      const res = await request(users)
        .post("/link-patient")
        .send({
          caregiverId: "caregiver1",
          patientId: "patient1"
        });

      expect(res.status).to.equal(500);
      expect(res.body.error).to.contain("already linked to another caregiver");
    });
  });

  describe("Firestore Database Triggers", () => {
    const { onReminderLogCreated, onReminderLogUpdated } = require("./index.js");

    beforeEach(() => {
      adminMock.lastSentMessage = null;
      store["patient1"] = {
        userId: "patient1",
        role: "Patient",
        name: "John Patient",
        fcmToken: "patient-fcm-token",
        linkedCaregiverId: "caregiver1",
      };
      store["caregiver1"] = {
        userId: "caregiver1",
        role: "Caregiver",
        name: "Jane Caregiver",
        fcmToken: "caregiver-fcm-token",
        linkedPatientId: "patient1",
      };
    });

    it("onReminderLogCreated should send FCM notification if status is Triggered", async () => {
      const snap = {
        id: "log123",
        data: () => ({
          patientId: "patient1",
          reminderId: "rem123",
          description: "Take BP Tablet",
          reminderType: "Medication",
          status: "Triggered",
          snoozeEnabled: true,
        }),
      };

      await onReminderLogCreated(snap, {});
      expect(adminMock.lastSentMessage).to.exist;
      expect(adminMock.lastSentMessage.token).to.equal("patient-fcm-token");
      expect(adminMock.lastSentMessage.notification.title).to.equal("Medication Reminder");
      expect(adminMock.lastSentMessage.notification.body).to.equal("Take BP Tablet");
      expect(adminMock.lastSentMessage.data.logId).to.equal("log123");
    });

    it("onReminderLogUpdated should send FCM notification to caregiver if status updates to Missed with escalationNotified=true", async () => {
      const change = {
        before: {
          data: () => ({
            patientId: "patient1",
            reminderId: "rem123",
            description: "Take BP Tablet",
            reminderType: "Medication",
            status: "Triggered",
            escalationNotified: false,
          }),
        },
        after: {
          id: "log123",
          data: () => ({
            patientId: "patient1",
            reminderId: "rem123",
            description: "Take BP Tablet",
            reminderType: "Medication",
            status: "Missed",
            escalationNotified: true,
          }),
        },
      };

      await onReminderLogUpdated(change, {});
      expect(adminMock.lastSentMessage).to.exist;
      expect(adminMock.lastSentMessage.token).to.equal("caregiver-fcm-token");
      expect(adminMock.lastSentMessage.notification.title).to.equal("Missed Reminder: Medication");
      expect(adminMock.lastSentMessage.notification.body).to.contain("John Patient missed");
    });
  });
});
