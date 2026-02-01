"use client";

import { useEffect } from "react";
import { getAppAnalytics } from "@/lib/firebase";

export function FirebaseAnalytics() {
  useEffect(() => {
    getAppAnalytics();
  }, []);
  return null;
}
