process.env.NODE_ENV = 'test';
const chai = require("chai");
const expect = chai.expect;
const request = require("supertest");

// 1. Setup Firestore Mock
const store = {};
const dbMock = {
  collection: (colName) => {
    const buildQuery = (initialFilters = []) => {
      const query = {
        filters: initialFilters,
        where: (f, o, v) => {
          query.filters.push([f, o, v]);
          return query;
        },
        orderBy: (f, d) => {
          query.orderByField = f;
          query.orderByDirection = d;
          return query;
        },
        startAfter: (val) => {
          query.filters.push(["timestamp", "startAfter", val]);
          return query;
        },
        limit: (val) => {
          query.limitVal = val;
          return query;
        },
        get: async () => {
          let docs = Object.keys(store).map(id => ({
            id,
            data: store[id]
          }));

          // Filter by collection type
          if (colName === "safeZones" || colName === "locationLogs" || colName === "alerts" || colName === "dailyBehavior" || colName === "weeklySummaries" || colName === "guidanceKnowledge") {
            docs = docs.filter(doc => doc.id.startsWith(`${colName}_`))
                       .map(doc => ({
                         id: doc.id.substring(colName.length + 1),
                         data: doc.data
                       }));
          } else {
            // Exclude prefixed documents
            docs = docs.filter(doc => !doc.id.startsWith("safeZones_") && !doc.id.startsWith("locationLogs_") && !doc.id.startsWith("alerts_") && !doc.id.startsWith("dailyBehavior_") && !doc.id.startsWith("weeklySummaries_") && !doc.id.startsWith("guidanceKnowledge_"));
            
            if (colName === "users") {
              docs = docs.filter(doc => doc.data.role === "Patient" || doc.data.role === "Caregiver");
            } else if (colName === "reminders") {
              docs = docs.filter(doc => doc.data.activeStatus !== undefined && doc.data.status === undefined);
            } else if (colName === "reminderLogs") {
              docs = docs.filter(doc => doc.data.status !== undefined);
            }
          }

          // Apply query filters
          for (const [f, o, v] of query.filters) {
            docs = docs.filter(doc => {
              const val = doc.data[f];
              if (o === "==") {
                if (val && typeof val.toDate === "function" && v && typeof v.toDate === "function") {
                  return val.toDate().getTime() === v.toDate().getTime();
                }
                if (val && typeof val.toDate === "function" && v instanceof Date) {
                  return val.toDate().getTime() === v.getTime();
                }
                if (val && typeof val.toDate === "function" && typeof v === "object" && v !== null && v._seconds !== undefined) {
                  return val.toDate().getTime() === new Date(v._seconds * 1000).getTime();
                }
                return val === v;
              } else if (o === "<=") {
                const valTime = (val && typeof val.toDate === "function") ? val.toDate().getTime() : new Date(val).getTime();
                const vTime = v instanceof Date ? v.getTime() : (v && typeof v.toDate === "function" ? v.toDate().getTime() : new Date(v).getTime());
                return valTime <= vTime;
              } else if (o === "in") {
                return Array.isArray(v) && v.includes(val);
              } else if (o === "startAfter") {
                const valTime = (val && typeof val.toDate === "function") ? val.toDate().getTime() : new Date(val).getTime();
                const vTime = (v && typeof v.toDate === "function") ? v.toDate().getTime() : (v instanceof Date ? v.getTime() : new Date(v).getTime());
                return valTime < vTime;
              }
              return true;
            });
          }

          // Sort by orderByField if set, otherwise default to "timestamp"
          const sortField = query.orderByField || "timestamp";
          const isDesc = query.orderByDirection === "desc" || query.orderByDirection === "DESCENDING" || !query.orderByDirection;
          docs.sort((a, b) => {
            const aVal = a.data[sortField];
            const bVal = b.data[sortField];
            const aTime = aVal ? (typeof aVal.toDate === "function" ? aVal.toDate().getTime() : new Date(aVal).getTime()) : 0;
            const bTime = bVal ? (typeof bVal.toDate === "function" ? bVal.toDate().getTime() : new Date(bVal).getTime()) : 0;
            return isDesc ? bTime - aTime : aTime - bTime;
          });

          if (query.limitVal !== undefined) {
            docs = docs.slice(0, query.limitVal);
          }

          return {
            empty: docs.length === 0,
            size: docs.length,
            docs: docs.map(doc => {
              const docRef = dbMock.collection(colName).doc(doc.id);
              return {
                id: doc.id,
                data: () => doc.data,
                ref: docRef
              };
            })
          };
        }
      };
      return query;
    };

    const ref = {
      doc: (id) => {
        const docId = id || `mock_id_${Math.random().toString(36).substr(2, 9)}`;
        const storeKey = (colName === "safeZones" || colName === "locationLogs" || colName === "alerts" || colName === "dailyBehavior" || colName === "weeklySummaries" || colName === "guidanceKnowledge") ? `${colName}_${docId}` : docId;
        const docRef = {
          id: docId,
          set: async (data) => {
            store[storeKey] = { ...data };
            return { writeTime: new Date() };
          },
          get: async () => {
            const data = store[storeKey];
            return {
              exists: !!data,
              data: () => data,
            };
          },
          update: async (data) => {
            if (!store[storeKey]) throw new Error("Doc does not exist");
            store[storeKey] = { ...store[storeKey], ...data };
            return { writeTime: new Date() };
          },
          delete: async () => {
            delete store[storeKey];
            return { writeTime: new Date() };
          }
        };
        return docRef;
      },
      where: (field, op, value) => {
        return buildQuery([[field, op, value]]);
      },
      get: async () => {
        return buildQuery([]).get();
      }
    };
    return ref;
  },
  runTransaction: async (handler) => {
    const transaction = {
      get: async (docRef) => docRef.get(),
      update: (docRef, data) => docRef.update(data)
    };
    return handler(transaction);
  },
  batch: () => {
    const operations = [];
    return {
      set: (docRef, data) => {
        operations.push(() => docRef.set(data));
      },
      delete: (docRef) => {
        operations.push(() => docRef.delete());
      },
      commit: async () => {
        for (const op of operations) {
          await op();
        }
      }
    };
  }
};

const adminMock = {
  initializeApp: () => {},
  firestore: Object.assign(() => dbMock, {
    FieldValue: {
      serverTimestamp: () => {
        const d = new Date();
        return {
          toDate: () => d
        };
      }
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
  },
  auth: {
    user: () => ({
      onDelete: (handler) => handler
    })
  },
  pubsub: {
    schedule: (scheduleStr) => ({
      onRun: (handler) => handler
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
const { users, onUserDeleted } = require("./index.js");

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

  describe("Scheduled Background Functions", () => {
    const { checkDueReminders, checkEscalation } = require("./index.js");

    beforeEach(() => {
      // Clear store
      for (const key in store) {
        delete store[key];
      }
    });

    it("checkDueReminders should trigger active reminders with scheduledTime in the past", async () => {
      const pastDate = new Date(Date.now() - 10000);
      const futureDate = new Date(Date.now() + 100000);

      // Save an active past reminder
      store["rem_past"] = {
        patientId: "patient1",
        description: "Take insulin",
        reminderType: "Medication",
        scheduledTime: {
          toDate: () => pastDate
        },
        activeStatus: true,
        snoozeEnabled: true
      };

      // Save an active future reminder
      store["rem_future"] = {
        patientId: "patient1",
        description: "Evening walk",
        reminderType: "Routine",
        scheduledTime: {
          toDate: () => futureDate
        },
        activeStatus: true,
        snoozeEnabled: true
      };

      // Save an inactive past reminder
      store["rem_inactive"] = {
        patientId: "patient1",
        description: "Check pressure",
        reminderType: "Medication",
        scheduledTime: {
          toDate: () => pastDate
        },
        activeStatus: false,
        snoozeEnabled: true
      };

      await checkDueReminders({});

      // Verify log was created for rem_past
      const logKeys = Object.keys(store).filter(k => k.startsWith("mock_id_") || store[k].status !== undefined);
      expect(logKeys.length).to.equal(1);
      const triggeredLog = store[logKeys[0]];
      expect(triggeredLog.reminderId).to.equal("rem_past");
      expect(triggeredLog.status).to.equal("Triggered");

      // Running checkDueReminders again should not create duplicate log
      await checkDueReminders({});
      const logKeysAfter = Object.keys(store).filter(k => k.startsWith("mock_id_") || store[k].status !== undefined);
      expect(logKeysAfter.length).to.equal(1);
    });

    it("checkEscalation should escalate triggered logs that exceed escalationWaitingDuration", async () => {
      const triggerTimePast = new Date(Date.now() - 20 * 60000); // 20 mins ago
      const triggerTimeRecent = new Date(Date.now() - 5 * 60000); // 5 mins ago

      // Reminder with 15 mins escalation limit
      store["rem_1"] = {
        escalationWaitingDuration: 15,
        activeStatus: true
      };

      // Triggered log 20 mins ago (due for escalation)
      store["log_past"] = {
        reminderId: "rem_1",
        status: "Triggered",
        actionTime: {
          toDate: () => triggerTimePast
        }
      };

      // Triggered log 5 mins ago (not due for escalation)
      store["log_recent"] = {
        reminderId: "rem_1",
        status: "Triggered",
        actionTime: {
          toDate: () => triggerTimeRecent
        }
      };

      await checkEscalation({});

      expect(store["log_past"].status).to.equal("Missed");
      expect(store["log_past"].escalationNotified).to.be.true;
      expect(store["log_recent"].status).to.equal("Triggered");
    });

    it("checkEscalation should escalate snoozed logs that exceed 5 minutes", async () => {
      const snoozeTimePast = new Date(Date.now() - 6 * 60000); // 6 mins ago
      const snoozeTimeRecent = new Date(Date.now() - 3 * 60000); // 3 mins ago

      store["log_snooze_past"] = {
        reminderId: "rem_1",
        status: "Snoozed",
        actionTime: {
          toDate: () => snoozeTimePast
        }
      };

      store["log_snooze_recent"] = {
        reminderId: "rem_1",
        status: "Snoozed",
        actionTime: {
          toDate: () => snoozeTimeRecent
        }
      };

      await checkEscalation({});

      expect(store["log_snooze_past"].status).to.equal("Missed");
      expect(store["log_snooze_past"].escalationNotified).to.be.true;
      expect(store["log_snooze_recent"].status).to.equal("Snoozed");
    });
  });

  describe("Safe Zone & Location Monitoring API", () => {
    beforeEach(() => {
      // Clear store and add fresh mock profiles
      for (const key in store) {
        delete store[key];
      }

      store["patient1"] = {
        userId: "patient1",
        role: "Patient",
        name: "Jimmy Patient",
        contactDetails: "jimmy@example.com",
        fcmToken: "patient-fcm-token",
        linkedCaregiverId: "caregiver1",
      };

      store["caregiver1"] = {
        userId: "caregiver1",
        role: "Caregiver",
        name: "Jane Caregiver",
        contactDetails: "jane@example.com",
        fcmToken: "caregiver-fcm-token",
        linkedPatientId: "patient1",
      };

      store["unlinked_caregiver"] = {
        userId: "unlinked_caregiver",
        role: "Caregiver",
        name: "Bob Caregiver",
        contactDetails: "bob@example.com",
        fcmToken: "bob-fcm-token",
        linkedPatientId: null,
      };
    });

    describe("POST /safezone/configure", () => {
      it("should successfully configure safe zone when requested by linked caregiver", async () => {
        const res = await request(users)
          .post("/safezone/configure")
          .send({
            caregiverId: "caregiver1",
            patientId: "patient1",
            homeLatitude: 37.7749,
            homeLongitude: -122.4194,
            radius: 200,
            activeStatus: true,
          });

        expect(res.status).to.equal(200);
        expect(res.body.message).to.equal("Safe zone configured successfully");
        expect(store["safeZones_patient1"]).to.exist;
        expect(store["safeZones_patient1"].homeLatitude).to.equal(37.7749);
      });

      it("should block configuration if requested by unlinked caregiver", async () => {
        const res = await request(users)
          .post("/safezone/configure")
          .send({
            caregiverId: "unlinked_caregiver",
            patientId: "patient1",
            homeLatitude: 37.7749,
            homeLongitude: -122.4194,
            radius: 200,
            activeStatus: true,
          });

        expect(res.status).to.equal(403);
        expect(res.body.error).to.contain("not linked to this patient");
      });

      it("should block configuration if coordinates are invalid", async () => {
        const res = await request(users)
          .post("/safezone/configure")
          .send({
            caregiverId: "caregiver1",
            patientId: "patient1",
            homeLatitude: 200, // Invalid lat
            homeLongitude: -122.4194,
            radius: 200,
            activeStatus: true,
          });

        expect(res.status).to.equal(400);
        expect(res.body.error).to.contain("Latitude must be a valid number");
      });
    });

    describe("GET /safezone/:patientId", () => {
      it("should retrieve safe zone settings", async () => {
        // Setup initial configuration
        store["safeZones_patient1"] = {
          patientId: "patient1",
          homeLatitude: 37.7749,
          homeLongitude: -122.4194,
          radius: 200,
          activeStatus: true,
        };

        const res = await request(users).get("/safezone/patient1");
        expect(res.status).to.equal(200);
        expect(res.body.radius).to.equal(200);
      });

      it("should return 404 if safe zone does not exist", async () => {
        const res = await request(users).get("/safezone/patient1");
        expect(res.status).to.equal(404);
      });
    });

    describe("POST /location/update", () => {
      beforeEach(() => {
        adminMock.lastSentMessage = null;
        store["safeZones_patient1"] = {
          patientId: "patient1",
          homeLatitude: 37.7749,
          homeLongitude: -122.4194,
          radius: 200,
          activeStatus: true,
        };
      });

      it("should log location as Inside and not send FCM when patient is within geofence", async () => {
        // Coordinates close to 37.7749, -122.4194
        const res = await request(users)
          .post("/location/update")
          .send({
            patientId: "patient1",
            latitude: 37.7749,
            longitude: -122.4193,
          });

        expect(res.status).to.equal(200);
        expect(res.body.status).to.equal("Inside");
        expect(res.body.breachFlag).to.be.false;
        expect(adminMock.lastSentMessage).to.be.null;

        // Verify log was saved
        const logKeys = Object.keys(store).filter(k => k.startsWith("locationLogs_"));
        expect(logKeys.length).to.equal(1);
        expect(store[logKeys[0]].status).to.equal("Inside");
      });

      it("should log location as Outside, trigger breach alert, and notify caregiver when patient exits geofence", async () => {
        const res = await request(users)
          .post("/location/update")
          .send({
            patientId: "patient1",
            latitude: 38.0,
            longitude: -122.0,
          });

        expect(res.status).to.equal(200);
        expect(res.body.status).to.equal("Outside");
        expect(res.body.breachFlag).to.be.true;

        // Verify caregiver was notified
        expect(adminMock.lastSentMessage).to.exist;
        expect(adminMock.lastSentMessage.token).to.equal("caregiver-fcm-token");
        expect(adminMock.lastSentMessage.notification.title).to.contain("Breach");
        expect(adminMock.lastSentMessage.data.distanceOutside).to.exist;

        // Verify alert was created
        expect(store["alerts_breach_patient1"]).to.exist;
        expect(store["alerts_breach_patient1"].resolved).to.be.false;
      });

      it("should apply cooldown and not send duplicate notifications for consecutive Outside logs", async () => {
        // Setup initial Outside log
        store["locationLogs_log1"] = {
          patientId: "patient1",
          latitude: 38.0,
          longitude: -122.0,
          status: "Outside",
          breachFlag: true,
          timestamp: {
            toDate: () => new Date(Date.now() - 60000)
          }
        };

        const res = await request(users)
          .post("/location/update")
          .send({
            patientId: "patient1",
            latitude: 38.001,
            longitude: -122.001,
          });

        expect(res.status).to.equal(200);
        expect(res.body.status).to.equal("Outside");
        
        // Cooldown should prevent sending a new notification
        expect(adminMock.lastSentMessage).to.be.null;
      });

      it("should detect re-entry when patient moves back inside and resolve breach alerts", async () => {
        // Setup initial Outside log & active alert
        store["locationLogs_log1"] = {
          patientId: "patient1",
          latitude: 38.0,
          longitude: -122.0,
          status: "Outside",
          breachFlag: true,
          timestamp: {
            toDate: () => new Date(Date.now() - 60000)
          }
        };

        store["alerts_breach_patient1"] = {
          patientId: "patient1",
          type: "SafeZoneBreach",
          resolved: false
        };

        const res = await request(users)
          .post("/location/update")
          .send({
            patientId: "patient1",
            latitude: 37.7749,
            longitude: -122.4194,
          });

        expect(res.status).to.equal(200);
        expect(res.body.status).to.equal("Inside");

        // Verify re-entry notification sent
        expect(adminMock.lastSentMessage).to.exist;
        expect(adminMock.lastSentMessage.notification.title).to.contain("Re-entered");

        // Verify alert was resolved
        expect(store["alerts_breach_patient1"].resolved).to.be.true;
      });
    });

    describe("POST /safezone/breach", () => {
      it("should force trigger a breach event, notify caregiver, and set isBreached in patient profile", async () => {
        const res = await request(users)
          .post("/safezone/breach")
          .send({
            patientId: "patient1",
            latitude: 38.0,
            longitude: -122.0,
          });

        expect(res.status).to.equal(200);
        expect(res.body.message).to.equal("Breach triggered successfully");

        // Verify notification was sent
        expect(adminMock.lastSentMessage).to.exist;
        expect(adminMock.lastSentMessage.token).to.equal("caregiver-fcm-token");
        expect(adminMock.lastSentMessage.notification.title).to.contain("Emergency: Safe Zone Breached!");

        // Verify isBreached state in user profile
        expect(store["patient1"].isBreached).to.be.true;

        // Verify a location log was written
        const logKeys = Object.keys(store).filter(k => k.startsWith("locationLogs_"));
        expect(logKeys.length).to.equal(1);
        expect(store[logKeys[0]].status).to.equal("Outside");
      });
    });

    describe("GET /locationLogs/:patientId with pagination", () => {
      it("should retrieve sorted location logs limited by query parameter", async () => {
        store["locationLogs_log1"] = {
          patientId: "patient1",
          timestamp: { toDate: () => new Date(Date.now() - 20000) },
          latitude: 37.7,
          longitude: -122.4,
          status: "Inside"
        };
        store["locationLogs_log2"] = {
          patientId: "patient1",
          timestamp: { toDate: () => new Date(Date.now() - 10000) },
          latitude: 37.8,
          longitude: -122.5,
          status: "Inside"
        };

        const res = await request(users)
          .get("/locationLogs/patient1")
          .query({ limit: 1 });

        expect(res.status).to.equal(200);
        expect(res.body.length).to.equal(1);
        expect(res.body[0].latitude).to.equal(37.8);
      });
    });

    describe("Unauthorized Access Tests", () => {
      beforeEach(() => {
        store["patient1"] = {
          userId: "patient1",
          role: "Patient",
          name: "Jimmy Patient",
          contactDetails: "jimmy@example.com",
          fcmToken: "patient-fcm-token",
          linkedCaregiverId: "caregiver1",
        };

        store["caregiver1"] = {
          userId: "caregiver1",
          role: "Caregiver",
          name: "Jane Caregiver",
          contactDetails: "jane@example.com",
          fcmToken: "caregiver-fcm-token",
          linkedPatientId: "patient1",
        };

        store["unlinked_caregiver"] = {
          userId: "unlinked_caregiver",
          role: "Caregiver",
          name: "Bob Caregiver",
          contactDetails: "bob@example.com",
          fcmToken: "bob-fcm-token",
          linkedPatientId: null,
        };
      });

      it("should reject registering a profile for a different UID", async () => {
        const res = await request(users)
          .post("/register")
          .set("x-mock-user-id", "attacker")
          .send({
            userId: "patient1",
            role: "Patient",
            name: "Spoofed John",
            contactDetails: "spoof@example.com"
          });

        expect(res.status).to.equal(403);
        expect(res.body.error).to.contain("Cannot register profile for another user ID");
      });

      it("should reject linking patient if caregiver is not authenticated user", async () => {
        const res = await request(users)
          .post("/link-patient")
          .set("x-mock-user-id", "attacker")
          .send({
            caregiverId: "caregiver1",
            patientId: "patient1"
          });

        expect(res.status).to.equal(403);
        expect(res.body.error).to.contain("Only the caregiver can link patient accounts");
      });

      it("should reject safezone configuration if caregiver is not authenticated user", async () => {
        const res = await request(users)
          .post("/safezone/configure")
          .set("x-mock-user-id", "attacker")
          .send({
            caregiverId: "caregiver1",
            patientId: "patient1",
            homeLatitude: 37.7,
            homeLongitude: -122.4,
            radius: 200,
            activeStatus: true
          });

        expect(res.status).to.equal(403);
        expect(res.body.error).to.contain("Only the caregiver can configure the safe zone");
      });

      it("should reject fetching safezone for unlinked caregiver", async () => {
        const res = await request(users)
          .get("/safezone/patient1")
          .set("x-mock-user-id", "unlinked_caregiver");

        expect(res.status).to.equal(403);
        expect(res.body.error).to.contain("Unauthorized access to safe zone configuration");
      });

      it("should reject location update if user updates another user's coordinate", async () => {
        const res = await request(users)
          .post("/location/update")
          .set("x-mock-user-id", "attacker")
          .send({
            patientId: "patient1",
            latitude: 37.7,
            longitude: -122.4
          });

        expect(res.status).to.equal(403);
        expect(res.body.error).to.contain("Cannot update location for another user");
      });

      it("should reject location history logs access for unlinked caregiver", async () => {
        const res = await request(users)
          .get("/locationLogs/patient1")
          .set("x-mock-user-id", "unlinked_caregiver");

        expect(res.status).to.equal(403);
        expect(res.body.error).to.contain("Unauthorized access to location history logs");
      });

      it("should reject geofence checking for unlinked caregiver", async () => {
        const res = await request(users)
          .post("/safezone/check")
          .set("x-mock-user-id", "unlinked_caregiver")
          .send({
            patientId: "patient1",
            latitude: 37.7,
            longitude: -122.4
          });

        expect(res.status).to.equal(403);
        expect(res.body.error).to.contain("Unauthorized access to geofence check");
      });

      it("should reject breach simulation for unlinked caregiver", async () => {
        const res = await request(users)
          .post("/safezone/breach")
          .set("x-mock-user-id", "unlinked_caregiver")
          .send({
            patientId: "patient1",
            latitude: 37.7,
            longitude: -122.4
          });

        expect(res.status).to.equal(403);
        expect(res.body.error).to.contain("Unauthorized access to breach simulation");
      });
    });

    describe("Unlink Patient API & Cleanup Triggers", () => {
      it("should successfully unlink caregiver and patient", async () => {
        store["patient1"] = {
          userId: "patient1",
          role: "Patient",
          linkedCaregiverId: "caregiver1"
        };
        store["caregiver1"] = {
          userId: "caregiver1",
          role: "Caregiver",
          linkedPatientId: "patient1"
        };

        const res = await request(users)
          .post("/unlink-patient")
          .set("x-mock-user-id", "caregiver1")
          .send({
            caregiverId: "caregiver1",
            patientId: "patient1"
          });

        expect(res.status).to.equal(200);
        expect(res.body.message).to.contain("successfully unlinked");
        expect(store["patient1"].linkedCaregiverId).to.be.null;
        expect(store["caregiver1"].linkedPatientId).to.be.null;
      });

      it("should reject unlinking if caller is unauthorized", async () => {
        store["patient1"] = {
          userId: "patient1",
          role: "Patient",
          linkedCaregiverId: "caregiver1"
        };
        store["caregiver1"] = {
          userId: "caregiver1",
          role: "Caregiver",
          linkedPatientId: "patient1"
        };

        const res = await request(users)
          .post("/unlink-patient")
          .set("x-mock-user-id", "attacker")
          .send({
            caregiverId: "caregiver1",
            patientId: "patient1"
          });

        expect(res.status).to.equal(403);
        expect(res.body.error).to.contain("not authorized to unlink");
      });

      it("onUserDeleted should delete patient user document, safe zones, and location logs", async () => {
        store["patient1"] = {
          userId: "patient1",
          role: "Patient",
          linkedCaregiverId: "caregiver1"
        };
        store["safeZones_patient1"] = {
          patientId: "patient1",
          radius: 200
        };
        store["locationLogs_log1"] = {
          patientId: "patient1",
          status: "Inside"
        };
        store["caregiver1"] = {
          userId: "caregiver1",
          role: "Caregiver",
          linkedPatientId: "patient1"
        };

        await onUserDeleted({ uid: "patient1" });

        expect(store["patient1"]).to.be.undefined;
        expect(store["safeZones_patient1"]).to.be.undefined;
        expect(store["locationLogs_log1"]).to.be.undefined;
        expect(store["caregiver1"].linkedPatientId).to.be.null;
      });

      it("onUserDeleted should delete caregiver user document and clear patient link", async () => {
        store["patient1"] = {
          userId: "patient1",
          role: "Patient",
          linkedCaregiverId: "caregiver1"
        };
        store["caregiver1"] = {
          userId: "caregiver1",
          role: "Caregiver",
          linkedPatientId: "patient1"
        };

        await onUserDeleted({ uid: "caregiver1" });

        expect(store["caregiver1"]).to.be.undefined;
        expect(store["patient1"].linkedCaregiverId).to.be.null;
      });
    });

    describe("Alert Escalation Engine API Tests", () => {
      beforeEach(() => {
        adminMock.lastSentMessage = null;
        store["patient1"] = {
          userId: "patient1",
          role: "Patient",
          name: "Jimmy Patient",
          contactDetails: "jimmy@example.com",
          fcmToken: "patient-fcm-token",
          linkedCaregiverId: "caregiver1",
        };
        store["caregiver1"] = {
          userId: "caregiver1",
          role: "Caregiver",
          name: "Jane Caregiver",
          contactDetails: "jane@example.com",
          fcmToken: "caregiver-fcm-token",
          linkedPatientId: "patient1",
        };
        store["unlinked_caregiver"] = {
          userId: "unlinked_caregiver",
          role: "Caregiver",
          name: "Bob Caregiver",
          contactDetails: "bob@example.com",
          fcmToken: "bob-fcm-token",
          linkedPatientId: null,
        };
      });

      it("POST /alerts/create should successfully create an alert and send Level 1 notification", async () => {
        const res = await request(users)
          .post("/alerts/create")
          .set("x-mock-user-id", "patient1")
          .send({
            patientId: "patient1",
            eventType: "Safe Zone Breach",
            severity: "High"
          });

        expect(res.status).to.equal(201);
        expect(res.body.message).to.equal("Alert created successfully");
        const alertId = res.body.alertId;
        expect(alertId).to.exist;

        const storedAlert = store[`alerts_${alertId}`];
        expect(storedAlert).to.exist;
        expect(storedAlert.patientId).to.equal("patient1");
        expect(storedAlert.eventType).to.equal("Safe Zone Breach");
        expect(storedAlert.severity).to.equal("High");
        expect(storedAlert.escalationLevel).to.equal("Level 1");
        expect(storedAlert.resolved).to.be.false;

        // Verify patient received Level 1 notification
        expect(adminMock.lastSentMessage).to.exist;
        expect(adminMock.lastSentMessage.token).to.equal("patient-fcm-token");
        expect(adminMock.lastSentMessage.notification.title).to.contain("Repeat Reminder");
      });

      it("POST /alerts/create should block unauthorized caller", async () => {
        const res = await request(users)
          .post("/alerts/create")
          .set("x-mock-user-id", "unlinked_caregiver")
          .send({
            patientId: "patient1",
            eventType: "Safe Zone Breach",
            severity: "High"
          });

        expect(res.status).to.equal(403);
        expect(res.body.error).to.contain("Forbidden");
      });

      it("GET /alerts/:patientId should retrieve alerts ordered by timestamp", async () => {
        // Setup mock alerts
        store["alerts_alert1"] = {
          patientId: "patient1",
          eventType: "Safe Zone Breach",
          severity: "High",
          alertTimestamp: new Date(Date.now() - 10000),
          escalationLevel: "Level 1",
          notificationStatus: "Sent",
          resolved: false
        };
        store["alerts_alert2"] = {
          patientId: "patient1",
          eventType: "Missed Reminder",
          severity: "Medium",
          alertTimestamp: new Date(),
          escalationLevel: "Level 2",
          notificationStatus: "Sent",
          resolved: false
        };

        const res = await request(users)
          .get("/alerts/patient1")
          .set("x-mock-user-id", "patient1");

        expect(res.status).to.equal(200);
        expect(res.body.length).to.equal(2);
        // Ordering should put newer alert (alert2) first
        expect(res.body[0].eventType).to.equal("Missed Reminder");
        expect(res.body[1].eventType).to.equal("Safe Zone Breach");
      });

      it("POST /alerts/escalate should progressively escalate level and trigger targeted FCM notifications", async () => {
        const alertId = "escalation_test_alert";
        store[`alerts_${alertId}`] = {
          patientId: "patient1",
          eventType: "Missed Reminder",
          severity: "High",
          alertTimestamp: new Date(),
          escalationLevel: "Level 1",
          resolved: false
        };

        // Escalate Level 1 -> Level 2 (Patient Reinforced Reminder)
        let res = await request(users)
          .post("/alerts/escalate")
          .set("x-mock-user-id", "caregiver1")
          .send({ alertId });

        expect(res.status).to.equal(200);
        expect(res.body.nextLevel).to.equal("Level 2");
        expect(store[`alerts_${alertId}`].escalationLevel).to.equal("Level 2");
        expect(adminMock.lastSentMessage.token).to.equal("patient-fcm-token");
        expect(adminMock.lastSentMessage.notification.title).to.contain("Urgent Reminder");

        // Escalate Level 2 -> Level 3 (Caregiver Notification)
        res = await request(users)
          .post("/alerts/escalate")
          .set("x-mock-user-id", "caregiver1")
          .send({ alertId });

        expect(res.status).to.equal(200);
        expect(res.body.nextLevel).to.equal("Level 3");
        expect(store[`alerts_${alertId}`].escalationLevel).to.equal("Level 3");
        expect(adminMock.lastSentMessage.token).to.equal("caregiver-fcm-token");
        expect(adminMock.lastSentMessage.notification.title).to.contain("Caregiver Alert");

        // Escalate Level 3 -> Level 4 (Emergency Contact Notification)
        res = await request(users)
          .post("/alerts/escalate")
          .set("x-mock-user-id", "caregiver1")
          .send({ alertId });

        expect(res.status).to.equal(200);
        expect(res.body.nextLevel).to.equal("Level 4");
        expect(store[`alerts_${alertId}`].escalationLevel).to.equal("Level 4");
        expect(adminMock.lastSentMessage.token).to.equal("caregiver-fcm-token");
        expect(adminMock.lastSentMessage.notification.title).to.contain("EMERGENCY");
      });

      it("POST /alerts/resolve should mark alert as resolved", async () => {
        const alertId = "resolve_test_alert";
        store[`alerts_${alertId}`] = {
          patientId: "patient1",
          eventType: "Missed Reminder",
          severity: "High",
          alertTimestamp: new Date(),
          escalationLevel: "Level 1",
          resolved: false
        };

        const res = await request(users)
          .post("/alerts/resolve")
          .set("x-mock-user-id", "patient1")
          .send({ alertId });

        expect(res.status).to.equal(200);
        expect(res.body.message).to.contain("successfully resolved");
        expect(store[`alerts_${alertId}`].resolved).to.be.true;
        expect(store[`alerts_${alertId}`].resolvedAt).to.exist;
      });
    });

    describe("Behavioral Stability Analysis API Tests", () => {
      beforeEach(() => {
        adminMock.lastSentMessage = null;
        store["patient1"] = {
          userId: "patient1",
          role: "Patient",
          name: "Jimmy Patient",
          contactDetails: "jimmy@example.com",
          fcmToken: "patient-fcm-token",
          linkedCaregiverId: "caregiver1",
        };
        store["caregiver1"] = {
          userId: "caregiver1",
          role: "Caregiver",
          name: "Jane Caregiver",
          contactDetails: "jane@example.com",
          fcmToken: "caregiver-fcm-token",
          linkedPatientId: "patient1",
        };
        store["unlinked_caregiver"] = {
          userId: "unlinked_caregiver",
          role: "Caregiver",
          name: "Bob Caregiver",
          contactDetails: "bob@example.com",
          fcmToken: "bob-fcm-token",
          linkedPatientId: null,
        };
      });

      it("POST /behavior/daily-score should successfully compute a stable score", async () => {
        const res = await request(users)
          .post("/behavior/daily-score")
          .set("x-mock-user-id", "patient1")
          .send({
            patientId: "patient1",
            date: "2026-07-12",
            hydrationAdherencePercentage: 90,
            medicationAdherencePercentage: 95,
            activityLevel: "high",
            safeZoneExits: 0,
            missedReminders: 0
          });

        expect(res.status).to.equal(201);
        expect(res.body.message).to.equal("Daily behavioral stability score computed successfully");
        expect(res.body.stabilityScore).to.be.at.least(80);
        expect(res.body.riskClassification).to.equal("Stable");
        expect(res.body.triggeredAlertId).to.be.null;

        const storedRecord = store["dailyBehavior_patient1_2026-07-12"];
        expect(storedRecord).to.exist;
        expect(storedRecord.hydrationAdherencePercentage).to.equal(90);
        expect(storedRecord.riskClassification).to.equal("Stable");
      });

      it("POST /behavior/daily-score should compute a high risk score and trigger a Behavioral Risk alert", async () => {
        const res = await request(users)
          .post("/behavior/daily-score")
          .set("x-mock-user-id", "caregiver1")
          .send({
            patientId: "patient1",
            date: "2026-07-11",
            hydrationAdherencePercentage: 20,
            medicationAdherencePercentage: 10,
            activityLevel: "low",
            safeZoneExits: 3,
            missedReminders: 4
          });

        expect(res.status).to.equal(201);
        expect(res.body.stabilityScore).to.be.below(50);
        expect(res.body.riskClassification).to.equal("High Risk");
        expect(res.body.triggeredAlertId).to.exist;

        const alertId = res.body.triggeredAlertId;
        const storedAlert = store[`alerts_${alertId}`];
        expect(storedAlert).to.exist;
        expect(storedAlert.eventType).to.equal("Behavioral Risk");
        expect(storedAlert.severity).to.equal("High");

        // Verify caregiver received FCM notification for high risk alert
        expect(adminMock.lastSentMessage).to.exist;
        expect(adminMock.lastSentMessage.token).to.equal("caregiver-fcm-token");
        expect(adminMock.lastSentMessage.notification.title).to.contain("High Behavioral Risk Alert");
      });

      it("GET /behavior/daily-score/:patientId should retrieve score for a specific date", async () => {
        store["dailyBehavior_patient1_2026-07-10"] = {
          patientId: "patient1",
          date: "2026-07-10",
          hydrationAdherencePercentage: 80,
          medicationAdherencePercentage: 85,
          activityLevel: "medium",
          safeZoneExits: 1,
          missedReminders: 1,
          stabilityScore: 75.0,
          riskClassification: "Moderate Risk"
        };

        const res = await request(users)
          .get("/behavior/daily-score/patient1")
          .query({ date: "2026-07-10" })
          .set("x-mock-user-id", "patient1");

        expect(res.status).to.equal(200);
        expect(res.body.stabilityScore).to.equal(75.0);
        expect(res.body.riskClassification).to.equal("Moderate Risk");
      });

      it("GET /behavior/history/:patientId should retrieve historical records sorted by date descending", async () => {
        store["dailyBehavior_patient1_2026-07-08"] = {
          patientId: "patient1",
          date: "2026-07-08",
          stabilityScore: 82.0,
          riskClassification: "Stable"
        };
        store["dailyBehavior_patient1_2026-07-09"] = {
          patientId: "patient1",
          date: "2026-07-09",
          stabilityScore: 78.0,
          riskClassification: "Moderate Risk"
        };

        const res = await request(users)
          .get("/behavior/history/patient1")
          .set("x-mock-user-id", "caregiver1");

        expect(res.status).to.equal(200);
        expect(res.body.length).to.equal(2);
        // Sorted desc by date
        expect(res.body[0].date).to.equal("2026-07-09");
        expect(res.body[1].date).to.equal("2026-07-08");
      });

      it("GET /behavior/history/:patientId should reject unauthorized access", async () => {
        const res = await request(users)
          .get("/behavior/history/patient1")
          .set("x-mock-user-id", "unlinked_caregiver");

        expect(res.status).to.equal(403);
        expect(res.body.error).to.contain("Forbidden");
      });
    });

    describe("Caregiver Dashboard API Tests", () => {
      beforeEach(() => {
        store["patient1"] = {
          userId: "patient1",
          role: "Patient",
          name: "Jimmy Patient",
          contactDetails: "jimmy@example.com",
          fcmToken: "patient-fcm-token",
          linkedCaregiverId: "caregiver1",
        };
        store["caregiver1"] = {
          userId: "caregiver1",
          role: "Caregiver",
          name: "Jane Caregiver",
          contactDetails: "jane@example.com",
          fcmToken: "caregiver-fcm-token",
          linkedPatientId: "patient1",
        };
        store["unlinked_caregiver"] = {
          userId: "unlinked_caregiver",
          role: "Caregiver",
          name: "Bob Caregiver",
          contactDetails: "bob@example.com",
          fcmToken: "bob-fcm-token",
          linkedPatientId: null,
        };
      });

      it("GET /dashboard/:patientId should successfully retrieve consolidated metrics", async () => {
        // Setup safeZone, behavior log, location log, alerts, weekly summary
        store["safeZones_patient1"] = {
          patientId: "patient1",
          homeLatitude: 37.7749,
          homeLongitude: -122.4194,
          radius: 200,
          activeStatus: true
        };
        store["locationLogs_log1"] = {
          patientId: "patient1",
          latitude: 37.8,
          longitude: -122.5,
          status: "Outside",
          timestamp: new Date()
        };
        store["dailyBehavior_patient1_2026-07-12"] = {
          patientId: "patient1",
          date: "2026-07-12",
          hydrationAdherencePercentage: 85.0,
          medicationAdherencePercentage: 90.0,
          stabilityScore: 88.0,
          riskClassification: "Stable"
        };
        store["alerts_active1"] = {
          patientId: "patient1",
          eventType: "Missed Reminder",
          severity: "High",
          alertTimestamp: new Date(),
          resolved: false
        };
        store["alerts_historical1"] = {
          patientId: "patient1",
          eventType: "Safe Zone Breach",
          severity: "Medium",
          alertTimestamp: new Date(Date.now() - 60000),
          resolved: true,
          resolvedAt: new Date()
        };
        store["weeklySummaries_sum1"] = {
          patientId: "patient1",
          insights: "Keep up the good hydration monitoring.",
          timestamp: new Date()
        };

        const res = await request(users)
          .get("/dashboard/patient1")
          .set("x-mock-user-id", "caregiver1");

        expect(res.status).to.equal(200);
        expect(res.body.medicationAdherence).to.equal(90.0);
        expect(res.body.hydrationAdherence).to.equal(85.0);
        expect(res.body.safeZoneStatus.configured).to.be.true;
        expect(res.body.safeZoneStatus.isBreached).to.be.true; // status is Outside
        expect(res.body.behavioralStability.score).to.equal(88.0);
        expect(res.body.activeAlerts.length).to.equal(1);
        expect(res.body.activeAlerts[0].eventType).to.equal("Missed Reminder");
        expect(res.body.historicalAlerts.length).to.equal(1);
        expect(res.body.weeklyInsightsPreview).to.equal("Keep up the good hydration monitoring.");
      });

      it("GET /dashboard/adherence/:patientId should calculate averages and counts", async () => {
        store["dailyBehavior_patient1_2026-07-11"] = {
          patientId: "patient1",
          date: "2026-07-11",
          hydrationAdherencePercentage: 80.0,
          medicationAdherencePercentage: 90.0,
          stabilityScore: 85.0,
          riskClassification: "Stable"
        };
        store["dailyBehavior_patient1_2026-07-12"] = {
          patientId: "patient1",
          date: "2026-07-12",
          hydrationAdherencePercentage: 60.0,
          medicationAdherencePercentage: 80.0,
          stabilityScore: 75.0,
          riskClassification: "Moderate Risk"
        };

        // Create 2 completed and 1 missed reminder logs within last 7 days
        store["reminderLogs_logcompleted1"] = {
          patientId: "patient1",
          status: "Completed",
          scheduledTime: new Date()
        };
        store["reminderLogs_logcompleted2"] = {
          patientId: "patient1",
          status: "Completed",
          scheduledTime: new Date(Date.now() - 100000)
        };
        store["reminderLogs_logmissed1"] = {
          patientId: "patient1",
          status: "Missed",
          scheduledTime: new Date()
        };

        const res = await request(users)
          .get("/dashboard/adherence/patient1")
          .set("x-mock-user-id", "patient1");

        expect(res.status).to.equal(200);
        expect(res.body.medicationAdherenceAverage).to.equal(85.0); // (90+80)/2
        expect(res.body.hydrationAdherenceAverage).to.equal(70.0);  // (80+60)/2
        expect(res.body.stabilityScoreAverage).to.equal(80.0);       // (85+75)/2
        expect(res.body.statusCounts.Completed).to.equal(2);
        expect(res.body.statusCounts.Missed).to.equal(1);
      });

      it("GET /dashboard/trends/:patientId should retrieve daily trends and weekly insights", async () => {
        store["dailyBehavior_patient1_2026-07-08"] = {
          patientId: "patient1",
          date: "2026-07-08",
          stabilityScore: 82.0,
          riskClassification: "Stable"
        };
        store["dailyBehavior_patient1_2026-07-09"] = {
          patientId: "patient1",
          date: "2026-07-09",
          stabilityScore: 78.0,
          riskClassification: "Moderate Risk"
        };
        store["weeklySummaries_sum1"] = {
          patientId: "patient1",
          insights: "Patient safe zones were maintained.",
          timestamp: new Date()
        };

        const res = await request(users)
          .get("/dashboard/trends/patient1")
          .set("x-mock-user-id", "caregiver1");

        expect(res.status).to.equal(200);
        expect(res.body.trends.length).to.equal(2);
        expect(res.body.trends[0].date).to.equal("2026-07-08"); // reverse sorted to older first
        expect(res.body.weeklyInsights).to.equal("Patient safe zones were maintained.");
      });

      it("GET /dashboard/:patientId should reject unauthorized access", async () => {
        const res = await request(users)
          .get("/dashboard/patient1")
          .set("x-mock-user-id", "unlinked_caregiver");

        expect(res.status).to.equal(403);
        expect(res.body.error).to.contain("Forbidden");
      });
    });

    describe("Weekly Insight Generation API Tests", () => {
      beforeEach(() => {
        store["patient1"] = {
          userId: "patient1",
          role: "Patient",
          name: "Jimmy Patient",
          contactDetails: "jimmy@example.com",
          fcmToken: "patient-fcm-token",
          linkedCaregiverId: "caregiver1",
        };
        store["caregiver1"] = {
          userId: "caregiver1",
          role: "Caregiver",
          name: "Jane Caregiver",
          contactDetails: "jane@example.com",
          fcmToken: "caregiver-fcm-token",
          linkedPatientId: "patient1",
        };
        store["unlinked_caregiver"] = {
          userId: "unlinked_caregiver",
          role: "Caregiver",
          name: "Bob Caregiver",
          contactDetails: "bob@example.com",
          fcmToken: "bob-fcm-token",
          linkedPatientId: null,
        };

        // Seed mock daily behavior data (7 days)
        for (let i = 1; i <= 7; i++) {
          const dateStr = `2026-07-0${i}`;
          store[`dailyBehavior_patient1_${dateStr}`] = {
            patientId: "patient1",
            date: dateStr,
            hydrationAdherencePercentage: 85.0,
            medicationAdherencePercentage: 90.0,
            activityLevel: "medium",
            safeZoneExits: 0,
            missedReminders: 0,
            stabilityScore: 88.0,
            riskClassification: "Stable"
          };
        }
      });

      it("POST /weekly-summary/generate should compute summary, query guidanceKnowledge RAG triggers, and keep latest 4 summaries", async () => {
        // Generate summary
        let res = await request(users)
          .post("/weekly-summary/generate")
          .set("x-mock-user-id", "caregiver1")
          .send({
            patientId: "patient1",
            weekId: "2026-W01"
          });

        expect(res.status).to.equal(201);
        expect(res.body.message).to.equal("Weekly summary generated successfully");
        const summaryId = res.body.summaryId;
        expect(summaryId).to.equal("patient1_2026-W01");

        const summary = store[`weeklySummaries_${summaryId}`];
        expect(summary).to.exist;
        expect(summary.averageStabilityScore).to.equal(88.0);
        expect(summary.hydrationAdherencePercentage).to.equal(85.0);
        expect(summary.medicationAdherencePercentage).to.equal(90.0);
        expect(summary.insightCards.length).to.be.at.least(1);

        // Verify safety rules: should not contain diagnosis words like "dementia", "alzheimer's" or clinical treatment advices.
        const summaryText = summary.weeklySummaryText.toLowerCase();
        expect(summaryText).to.not.contain("diagnose");
        expect(summaryText).to.not.contain("dementia");

        // Retention Policy: Create 4 more summaries to check if older ones are pruned (keep latest 4)
        for (let w = 2; w <= 5; w++) {
          await new Promise(resolve => setTimeout(resolve, 10));
          await request(users)
            .post("/weekly-summary/generate")
            .set("x-mock-user-id", "caregiver1")
            .send({
              patientId: "patient1",
              weekId: `2026-W0${w}`
            });
        }

        // We generated W1, W2, W3, W4, W5. Oldest (W1) should be deleted, leaving W2, W3, W4, W5.
        expect(store["weeklySummaries_patient1_2026-W01"]).to.be.undefined;
        expect(store["weeklySummaries_patient1_2026-W02"]).to.exist;
        expect(store["weeklySummaries_patient1_2026-W05"]).to.exist;
      });

      it("GET /weekly-summary/:patientId should retrieve summaries sorted by timestamp descending", async () => {
        store["weeklySummaries_sum1"] = {
          patientId: "patient1",
          weekId: "2026-W01",
          averageStabilityScore: 85.0,
          timestamp: new Date(Date.now() - 100000)
        };
        store["weeklySummaries_sum2"] = {
          patientId: "patient1",
          weekId: "2026-W02",
          averageStabilityScore: 90.0,
          timestamp: new Date()
        };

        const res = await request(users)
          .get("/weekly-summary/patient1")
          .set("x-mock-user-id", "patient1");

        expect(res.status).to.equal(200);
        expect(res.body.length).to.equal(2);
        // Order by timestamp desc
        expect(res.body[0].weekId).to.equal("2026-W02");
        expect(res.body[1].weekId).to.equal("2026-W01");
      });

      it("GET /weekly-summary/:patientId should block unauthorized caller", async () => {
        const res = await request(users)
          .get("/weekly-summary/patient1")
          .set("x-mock-user-id", "unlinked_caregiver");

        expect(res.status).to.equal(403);
        expect(res.body.error).to.contain("Forbidden");
      });
    });

    describe("SOS Emergency System API Tests", () => {
      beforeEach(() => {
        store["patient1"] = {
          userId: "patient1",
          role: "Patient",
          name: "Jimmy Patient",
          contactDetails: "jimmy@example.com",
          fcmToken: "patient-fcm-token",
          linkedCaregiverId: "caregiver1",
          emergencyContacts: [
            { name: "Emergency Contact 1", phone: "123-456", fcmToken: "emergency-fcm-token-1" }
          ]
        };
        store["caregiver1"] = {
          userId: "caregiver1",
          role: "Caregiver",
          name: "Jane Caregiver",
          contactDetails: "jane@example.com",
          fcmToken: "caregiver-fcm-token",
          linkedPatientId: "patient1",
        };
        store["unlinked_caregiver"] = {
          userId: "unlinked_caregiver",
          role: "Caregiver",
          name: "Bob Caregiver",
          contactDetails: "bob@example.com",
          fcmToken: "bob-fcm-token",
          linkedPatientId: null,
        };
      });

      it("POST /sos/trigger should successfully create high severity alert and notify caregiver and emergency contacts", async () => {
        const res = await request(users)
          .post("/sos/trigger")
          .set("x-mock-user-id", "patient1")
          .send({ patientId: "patient1" });

        expect(res.status).to.equal(201);
        expect(res.body.message).to.equal("SOS alert triggered successfully");
        const alertId = res.body.alertId;
        expect(alertId).to.exist;

        const alert = store[`alerts_${alertId}`];
        expect(alert).to.exist;
        expect(alert.eventType).to.equal("SOS Trigger");
        expect(alert.severity).to.equal("HIGH");
        expect(alert.escalationLevel).to.equal("Level 4");
        expect(alert.resolved).to.be.false;

        // Verify caregiver and emergency contact notifications were dispatched (testing adminMock.lastSentMessage)
        expect(adminMock.lastSentMessage).to.exist;
        expect(adminMock.lastSentMessage.notification.title).to.contain("SOS Emergency");
        expect(adminMock.lastSentMessage.data.escalationLevel).to.equal("Level 4");
      });

      it("POST /sos/trigger should block unauthorized caller", async () => {
        const res = await request(users)
          .post("/sos/trigger")
          .set("x-mock-user-id", "unlinked_caregiver")
          .send({ patientId: "patient1" });

        expect(res.status).to.equal(403);
        expect(res.body.error).to.contain("Forbidden");
      });
    });
  });
});
