import { initializeApp } from "firebase/app";
import { getAnalytics } from "firebase/analytics";

// Your web app's Firebase configuration
const firebaseConfig = {
  apiKey: "AIzaSyCshZiCFX7djYdP5GZ6g0P7qaz4Lt7OvVE",
  authDomain: "supplymapper.firebaseapp.com",
  projectId: "supplymapper",
  storageBucket: "supplymapper.firebasestorage.app",
  messagingSenderId: "1053711084660",
  appId: "1:1053711084660:web:5c1c1ae7cf48c91558b521",
  measurementId: "G-1BL9XQ11RF",
};

// Initialize Firebase
const app = initializeApp(firebaseConfig);

// Call only in the browser (e.g. from a client component) to avoid SSR errors
export function getAppAnalytics() {
  if (typeof window === "undefined") return null;
  return getAnalytics(app);
}

export { app };
