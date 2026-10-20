/* Firebase Messaging Service Worker */
importScripts('https://www.gstatic.com/firebasejs/10.7.1/firebase-app-compat.js');
importScripts('https://www.gstatic.com/firebasejs/10.7.1/firebase-messaging-compat.js');

firebase.initializeApp({
  apiKey: "AIzaSyD9icq-KItmRMBHvGr_udUN_qLPZhGhqeI",
  appId: "1:365872702190:web:70d7ad4b0eaa17457109ff",
  messagingSenderId: "365872702190",
  projectId: "memora-3b359",
  authDomain: "memora-3b359.firebaseapp.com",
  storageBucket: "memora-3b359.firebasestorage.app"
});

const messaging = firebase.messaging();

messaging.onBackgroundMessage(function(payload) {
  console.log('[firebase-messaging-sw.js] Received background message: ', payload);
  const notificationTitle = payload.notification?.title || 'Memora Reminder';
  const notificationOptions = {
    body: payload.notification?.body || '',
    icon: '/icons/Icon-192.png'
  };
  return self.registration.showNotification(notificationTitle, notificationOptions);
});
