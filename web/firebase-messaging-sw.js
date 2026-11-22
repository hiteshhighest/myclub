// Firebase Messaging service worker. Background notification payloads are
// displayed by the Firebase Messaging SDK while the site is not focused.
self.addEventListener('notificationclick', (event) => {
  event.notification.close();
  event.waitUntil(self.clients.openWindow(new URL('/', self.location.origin)));
});

importScripts('https://www.gstatic.com/firebasejs/13.3.0/firebase-app-compat.js');
importScripts('https://www.gstatic.com/firebasejs/13.3.0/firebase-messaging-compat.js');

firebase.initializeApp({
  apiKey: 'AIzaSyB-EcGA4qJAcvwepEjOXlZjq3Y9pxjOAt0',
  authDomain: 'myclub-942cf.firebaseapp.com',
  projectId: 'myclub-942cf',
  storageBucket: 'myclub-942cf.firebasestorage.app',
  messagingSenderId: '977835606748',
  appId: '1:977835606748:web:5ac4311fff3955e680ea19',
  measurementId: 'G-T8D1W494ZP',
});

firebase.messaging();
