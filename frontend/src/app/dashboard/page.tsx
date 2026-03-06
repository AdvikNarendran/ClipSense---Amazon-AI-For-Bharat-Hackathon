'use client';

import { useEffect, useState } from "react";
import AttentionCurveChart from "@/components/AttentionCurveChart";
import type { AttentionPoint } from "@/lib/types";
import { getProjects, type Project } from "@/lib/api";

export default function DashboardPage() {
  const [projects, setProjects] = useState<Project[]>([]);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    let cancelled = false;
    async function load() {
      try {
        const data = await getProjects();
        if (!cancelled) setProjects(data);
      } catch {
        // ignore
      } finally {
        if (!cancelled) setLoading(false);
      }
    }
    load();
    return () => { cancelled = true; };
  }, []);

  // Build attention curve from the latest project's clips
  const data: AttentionPoint[] = (() => {
    const latest = projects.find((p) => p.status === "done" && p.clips?.length);
    if (!latest) {
      // Fallback
      const arr: AttentionPoint[] = [];
      for (let t = 0; t <= 60; t++) {
        const v = Math.max(0, Math.min(100, 90 - t * 0.9 + 8 * Math.sin(t / 4)));
        arr.push({ t, v: Math.round(v) });
      }
      return arr;
    }

    const points: AttentionPoint[] = [{ t: 0, v: 30 }];
    latest.clips
      .sort((a, b) => a.startTime - b.startTime)
      .forEach((clip) => {
        points.push({ t: Math.max(0, clip.startTime - 2), v: 20 });
        points.push({
          t: (clip.startTime + clip.endTime) / 2,
          v: Math.min(100, clip.viralScore * 10),
        });
        points.push({ t: clip.endTime + 2, v: 25 });
      });
    return points;
  })();

  return (
    <main className="min-h-screen p-6">
      <div className="max-w-4xl mx-auto space-y-6">
        <h1 className="text-3xl font-extrabold">Dashboard</h1>
        {loading ? (
          <div className="wf-panel p-10 text-center animate-pulse text-black/60">
            Loading…
          </div>
        ) : (
          <div className="wf-panel p-5 rounded-2xl">
            <AttentionCurveChart data={data} title="Latest Attention Curve" />
          </div>
        )}
      </div>
    </main>
  );
}