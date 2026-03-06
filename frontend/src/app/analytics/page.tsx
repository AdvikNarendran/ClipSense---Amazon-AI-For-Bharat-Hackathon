'use client';

import Link from "next/link";
import { useEffect, useMemo, useState } from "react";
import { getProjects, type Project } from "@/lib/api";
import {
  ResponsiveContainer,
  LineChart,
  Line,
  CartesianGrid,
  XAxis,
  YAxis,
  Tooltip,
} from "recharts";

export default function AnalyticsPage() {
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

  // Aggregate stats
  const stats = useMemo(() => {
    const done = projects.filter((p) => p.status === "done");
    const totalClips = done.reduce((sum, p) => sum + p.clipCount, 0);
    const avgEng = done.length
      ? (done.reduce((sum, p) => sum + p.avgEngagement, 0) / done.length).toFixed(1)
      : "—";

    // Find the best clip across all projects
    let bestTime = "—";
    let bestProjectName = "—";
    let bestScore = 0;
    done.forEach((p) => {
      p.clips?.forEach((c) => {
        if (c.viralScore > bestScore) {
          bestScore = c.viralScore;
          const m = Math.floor(c.startTime / 60);
          const s = Math.floor(c.startTime % 60);
          bestTime = `${String(m).padStart(2, "0")}:${String(s).padStart(2, "0")}`;
          bestProjectName = p.title;
        }
      });
    });

    return { totalClips, avgEng, bestTime, bestProjectName, totalProjects: projects.length };
  }, [projects]);

  // Engagement trend by project
  const data = useMemo(() => {
    const done = projects
      .filter((p) => p.status === "done")
      .sort((a, b) => new Date(a.createdAt).getTime() - new Date(b.createdAt).getTime());

    if (done.length === 0) {
      return [{ name: "No data", score: 0 }];
    }

    return done.map(p => ({
      name: p.title.length > 15 ? p.title.slice(0, 12) + "..." : p.title,
      fullName: p.title,
      score: p.avgEngagement
    }));
  }, [projects]);

  if (loading) {
    return (
      <div className="wf-panel p-10 text-center text-black/60 animate-pulse">
        Loading analytics…
      </div>
    );
  }

  return (
    <div className="min-h-[calc(100vh-200px)] flex flex-col">
      <h1 className="text-3xl font-medium mb-10">Analytics</h1>

      <div className="grid grid-cols-1 lg:grid-cols-[1.3fr_0.7fr] gap-10 items-start">
        {/* Left: Attention Curve */}
        <div>
          <div className="text-sm font-medium mb-3">
            Engagement Trend (Avg. Score by Project)
          </div>

          <div className="wf-panel p-6 rounded-[18px]">
            <div className="wf-panel p-5 bg-white h-[320px] rounded-[14px]">
              <ResponsiveContainer width="100%" height="100%">
                <LineChart data={data}>
                  <CartesianGrid strokeDasharray="0" opacity={0.25} vertical={false} />
                  <XAxis
                    dataKey="name"
                    interval={0}
                    tick={{ fontSize: 10 }}
                  />
                  <YAxis
                    domain={[0, 100]}
                    label={{ value: "Engagement (0-100)", angle: -90, position: "insideLeft", offset: 15 }}
                  />
                  <Tooltip labelFormatter={(_, payload) => payload[0]?.payload.fullName} />
                  <Line type="monotone" dataKey="score" stroke="#B7561F" strokeWidth={3} dot={{ r: 6, fill: "#A89E53", strokeWidth: 0 }} activeDot={{ r: 8 }} />
                </LineChart>
              </ResponsiveContainer>
            </div>
          </div>
        </div>

        {/* Right: Stats cards */}
        <div className="space-y-6">
          <div className="wf-stat rounded-[16px] py-6">
            <div className="text-sm font-medium">Total Projects</div>
            <div className="mt-2 text-lg font-semibold">{stats.totalProjects}</div>
          </div>

          <div className="wf-stat rounded-[16px] py-6">
            <div className="text-sm font-medium">Total Clips</div>
            <div className="mt-2 text-lg font-semibold">{stats.totalClips}</div>
          </div>

          <div className="wf-stat rounded-[16px] py-6">
            <div className="text-sm font-medium">Avg. Engagement</div>
            <div className="mt-2 text-lg font-semibold">{stats.avgEng}/100</div>
          </div>

          <div className="wf-stat rounded-[16px] py-6">
            <div className="text-sm font-medium">Best Moment</div>
            <div className="mt-2">
              <div className="text-lg font-semibold">{stats.bestTime}</div>
              <div className="text-xs text-black/50 truncate max-w-[180px]" title={stats.bestProjectName}>
                in {stats.bestProjectName}
              </div>
            </div>
          </div>
        </div>
      </div>

      {/* Back */}
      <div className="mt-auto pt-10 flex items-center gap-3 text-sm">
        <Link href="/projects" className="flex items-center gap-3">
          <div className="h-9 w-9 rounded-full border border-black/30 bg-white flex items-center justify-center">
            ←
          </div>
          <span className="uppercase tracking-widest">Back to Projects</span>
        </Link>
      </div>
    </div>
  );
}