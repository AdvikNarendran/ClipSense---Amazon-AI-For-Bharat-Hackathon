'use client';

import { useEffect } from "react";
import { useRouter } from "next/navigation";
import { useAuth } from "@/context/AuthContext";
import AuthFlow from "@/components/AuthFlow";

export default function Home() {
  const { user, loading } = useAuth();
  const router = useRouter();

  useEffect(() => {
    if (!loading && user) {
      router.push("/projects");
    }
  }, [user, loading, router]);

  if (loading) {
    return (
      <div className="flex items-center justify-center animate-pulse py-20">
        <h1 className="text-5xl font-extrabold tracking-wide">
          <span style={{ color: "#A89E53" }}>Clip</span>
          <span style={{ color: "#B7561F" }}>Sense</span>
        </h1>
      </div>
    );
  }

  if (user) {
    return (
      <div className="flex items-center justify-center py-20">
        <div className="text-white text-xl">Redirecting to project...</div>
      </div>
    );
  }

  return (
    <div className="w-full max-w-md mx-auto">
      <AuthFlow />
    </div>
  );
}