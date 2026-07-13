importScripts("https://www.gstatic.com/firebasejs/10.7.1/firebase-app-compat.js");
importScripts("https://www.gstatic.com/firebasejs/10.7.1/firebase-messaging-compat.js");

firebase.initializeApp({
  apiKey: "AIzaSyCrTgX1_dLFcuijKpKju4UbZYV3fOBW3TQ",
  authDomain: "as-jala.firebaseapp.com",
  projectId: "as-jala",
  storageBucket: "as-jala.firebasestorage.app",
  messagingSenderId: "135540186701",
  appId: "1:135540186701:web:66d90975c186dae2d7c604",
});

const messaging = firebase.messaging();

messaging.onBackgroundMessage((payload) => {
  console.log("[firebase-messaging-sw.js] Background message received:", payload);
  const title = payload.notification?.title ?? "إشعار جديد";
  const body = payload.notification?.body ?? "";
  self.registration.showNotification(title, {
    body,
    icon: "/icons/Icon-192.png",
    badge: "/icons/Icon-192.png",
    data: payload.data ?? {},
    dir: "rtl",
    lang: "ar",
  });
});

self.addEventListener("notificationclick", (event) => {
  event.notification.close();
  event.waitUntil(
    clients.matchAll({ type: "window", includeUncontrolled: true }).then((clientList) => {
      if (clientList.length > 0) {
        return clientList[0].focus();
      }
      return clients.openWindow("/");
    })
  );
});
