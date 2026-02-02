import { initializeApp } from "firebase/app";
import { getAnalytics } from "firebase/analytics";

// Your web app's Firebase configuration
const firebaseConfig = {
  apiKey: "AIzaSyCshZiCFX7djYdP5GZ6g0P7qaz4Lt7OvVE",
  authDomain: "supplymapper.firebaseapp.com",
  projectId: "supplymapper",
  storageBucket: "supplymapper.firebasestorage.app",
  messagingSenderId: "1053711084660",
  appId: "1:1053711084660:web:62622b2b429cb76658b521",
  measurementId: "G-4NLTRCF3JF",
};

// Initialize Firebase
const app = initializeApp(firebaseConfig);

// Call only in the browser (e.g. from a client component) to avoid SSR errors
export function getAppAnalytics() {
  if (typeof window === "undefined") return null;
  return getAnalytics(app);
}

export { app };
