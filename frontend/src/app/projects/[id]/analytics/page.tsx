'use client';

import Link from "next/link";
import { useParams } from "next/navigation";
import { useEffect, useMemo, useState } from "react";
import {
  getProject, getEmotionData, getAttentionCurve,
  type Project, type EmotionScore, type AttentionCurveData,
} from "@/lib/api";
import {
  ResponsiveContainer,
  AreaChart, Area,
  LineChart, Line,
  BarChart, Bar, Cell,
  CartesianGrid, XAxis, YAxis, Tooltip, Legend,
} from "recharts";

export default function ProjectAnalyticsPage() {
  const { id } = useParams<{ id: string }>();
  const [project, setProject] = useState<Project | null>(null);
  const [emotionData, setEmotionData] = useState<EmotionScore[]>([]);
  const [attentionData, setAttentionData] = useState<AttentionCurveData | null>(null);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    let cancelled = false;
    async function load() {
      try {
        const [proj, emo, att] = await Promise.all([
          getProject(id),
          getEmotionData(id).catch(() => []),
          getAttentionCurve(id).catch(() => null),
        ]);
        if (!cancelled) {
          setProject(proj);
          setEmotionData(emo);
          setAttentionData(att);
        }
      } catch {
        // ignore
      } finally {
        if (!cancelled) setLoading(false);
      }
    }
    load();
    return () => { cancelled = true; };
  }, [id]);

  // Format emotion data for stacked area chart
  const emotionChartData = useMemo(() => {
    if (!emotionData || !emotionData.length) return [];
    return emotionData.map((e) => ({
      time: Math.round(e.timestamp),
      Joy: +(e.joy * 100).toFixed(0),
      Sadness: +(e.sadness * 100).toFixed(0),
      Anger: +(e.anger * 100).toFixed(0),
      Surprise: +(e.surprise * 100).toFixed(0),
      Neutral: +(e.neutral * 100).toFixed(0),
      Intensity: +(e.intensity * 100).toFixed(0),
    }));
  }, [emotionData]);

  // Attention curve data
  const curveData = useMemo(() => {
    if (!attentionData?.curve?.length) {
      // Fallback: build from clip data
      if (!project?.clips?.length) return [];
      const points: { t: number; v: number }[] = [{ t: 0, v: 30 }];
      [...project.clips].sort((a, b) => a.startTime - b.startTime).forEach((clip) => {
        points.push({ t: Math.max(0, clip.startTime - 2), v: 20 });
        points.push({ t: (clip.startTime + clip.endTime) / 2, v: Math.min(100, clip.viralScore) });
        points.push({ t: clip.endTime + 2, v: 25 });
      });
      return points;
    }
    return attentionData.curve.map((p) => ({ t: Math.round(p.timestamp), v: p.score }));
  }, [attentionData, project]);

  // Stats
  const topMoment = useMemo(() => {
    if (!project?.clips?.length) return "—";
    const best = [...project.clips].sort((a, b) => b.viralScore - a.viralScore)[0];
    const m = Math.floor(best.startTime / 60);
    const s = Math.floor(best.startTime % 60);
    return `${String(m).padStart(2, "0")}:${String(s).padStart(2, "0")}`;
  }, [project]);

  const dominantEmotion = useMemo(() => {
    if (!emotionData || !emotionData.length) return "—";
    const totals = { Joy: 0, Sadness: 0, Anger: 0, Surprise: 0, Neutral: 0 };
    emotionData.forEach((e) => {
      totals.Joy += e.joy;
      totals.Sadness += e.sadness;
      totals.Anger += e.anger;
      totals.Surprise += e.surprise;
      totals.Neutral += e.neutral;
    });
    const sorted = Object.entries(totals).sort((a, b) => b[1] - a[1]);
    return sorted[0][0];
  }, [emotionData]);

  if (loading) {
    return (
      <div className="wf-panel p-10 text-center text-black/60 animate-pulse">
        Loading analytics…
      </div>
    );
  }

  return (
    <div className="min-h-[calc(100vh-200px)] flex flex-col">
      <h1 className="text-3xl font-medium mb-10">Project Analytics</h1>

      {/* Clip Performance Comparison (Video-based) */}
      <div className="mb-10">
        <div className="text-sm font-medium mb-3">Clip Virality Comparison</div>
        <div className="wf-panel p-6 rounded-[18px]">
          <div className="wf-panel p-5 bg-white h-[350px] rounded-[14px]">
            {project?.clips && project.clips.length > 0 ? (
              <ResponsiveContainer width="100%" height="100%">
                <BarChart
                  data={project.clips.map((c, i) => ({
                    name: c.hookTitle ? (c.hookTitle.length > 20 ? c.hookTitle.substring(0, 17) + "..." : c.hookTitle) : `Clip ${i + 1}`,
                    score: c.viralScore,
                    fullTitle: c.hookTitle || `Clip ${i + 1}`
                  }))}
                  margin={{ top: 20, right: 30, left: 20, bottom: 60 }}
                >
                  <CartesianGrid strokeDasharray="3 3" vertical={false} opacity={0.2} />
                  <XAxis
                    dataKey="name"
                    angle={-45}
                    textAnchor="end"
                    interval={0}
                    height={80}
                    tick={{ fontSize: 11 }}
                  />
                  <YAxis domain={[0, 100]} label={{ value: "Viral Score", angle: -90, position: "insideLeft" }} />
                  <Tooltip
                    cursor={{ fill: 'rgba(0,0,0,0.05)' }}
                    content={({ active, payload }) => {
                      if (active && payload && payload.length) {
                        return (
                          <div className="bg-white p-3 border border-black/10 shadow-xl rounded-lg">
                            <p className="font-bold text-xs uppercase tracking-wider">{payload[0].payload.fullTitle}</p>
                            <p className="text-orange-600 font-black text-xl">{payload[0].value}%</p>
                          </div>
                        );
                      }
                      return null;
                    }}
                  />
                  <Bar dataKey="score" radius={[6, 6, 0, 0]}>
                    {project.clips.map((entry, index) => (
                      <Cell
                        key={`cell-${index}`}
                        fill={entry.viralScore > 80 ? "#B7561F" : entry.viralScore > 50 ? "#DAA520" : "#9ca3af"}
                      />
                    ))}
                  </Bar>
                </BarChart>
              </ResponsiveContainer>
            ) : (
              <div className="h-full flex items-center justify-center text-black/40 italic">
                No clips available for comparison.
              </div>
            )}
          </div>
          <p className="mt-4 text-xs text-black/50 text-center">
            Comparing individual clip virality scores side-by-side.
            <span className="ml-2 font-bold" style={{ color: "#B7561F" }}>■ High Potential</span>
            <span className="ml-2 font-bold" style={{ color: "#DAA520" }}>■ Medium Potential</span>
          </p>
        </div>
      </div>

      {/* Attention Curve + Stats */}
      <div className="grid grid-cols-1 lg:grid-cols-[1.3fr_0.7fr] gap-10 items-start mb-10">
        <div>
          <div className="text-sm font-medium mb-3">Attention Curve</div>
          <div className="wf-panel p-6 rounded-[18px]">
            <div className="wf-panel p-5 bg-white h-[320px] rounded-[14px]">
              {curveData.length > 0 ? (
                <ResponsiveContainer width="100%" height="100%">
                  <LineChart data={curveData}>
                    <CartesianGrid strokeDasharray="0" opacity={0.25} />
                    <XAxis dataKey="t" label={{ value: "Time (s)", position: "insideBottom", offset: -5 }} />
                    <YAxis domain={[0, 100]} label={{ value: "Attention", angle: -90, position: "insideLeft" }} />
                    <Tooltip />
                    <Line type="monotone" dataKey="v" stroke="#B7561F" strokeWidth={3} dot={false} name="Attention" />
                  </LineChart>
                </ResponsiveContainer>
              ) : (
                <div className="h-full flex items-center justify-center text-black/40 italic">
                  Attention curve not yet generated.
                </div>
              )}
            </div>
          </div>
        </div>

        <div className="space-y-6">
          <div className="wf-stat rounded-[16px] py-6">
            <div className="text-sm font-medium">No. of Clips</div>
            <div className="mt-2 text-lg font-semibold">{project?.clipCount ?? 0}</div>
          </div>
          <div className="wf-stat rounded-[16px] py-6">
            <div className="text-sm font-medium">Avg. Engagement</div>
            <div className="mt-2 text-lg font-semibold">
              {project?.avgEngagement ? `${project.avgEngagement}/100` : "—"}
            </div>
          </div>
          <div className="wf-stat rounded-[16px] py-6">
            <div className="text-sm font-medium">Top Moment</div>
            <div className="mt-2 text-lg font-semibold">{topMoment}</div>
          </div>
          <div className="wf-stat rounded-[16px] py-6">
            <div className="text-sm font-medium">Dominant Emotion</div>
            <div className="mt-2 text-lg font-semibold">{dominantEmotion}</div>
          </div>
          {attentionData && (
            <div className="wf-stat rounded-[16px] py-6">
              <div className="text-sm font-medium">Peak Moments</div>
              <div className="mt-2 text-lg font-semibold">{attentionData.peakMoments}</div>
            </div>
          )}
        </div>
      </div>

      <div className="mb-10">
        <div className="text-sm font-medium mb-3">Emotion Timeline</div>
        <div className="wf-panel p-6 rounded-[18px]">
          <div className="wf-panel p-5 bg-white h-[320px] rounded-[14px]">
            {emotionChartData.length > 0 ? (
              <ResponsiveContainer width="100%" height="100%">
                <AreaChart data={emotionChartData}>
                  <CartesianGrid strokeDasharray="0" opacity={0.15} />
                  <XAxis dataKey="time" label={{ value: "Time (s)", position: "insideBottom", offset: -5 }} />
                  <YAxis domain={[0, 100]} label={{ value: "Score %", angle: -90, position: "insideLeft" }} />
                  <Tooltip />
                  <Legend />
                  <Area type="monotone" dataKey="Joy" stackId="1" stroke="#f59e0b" fill="#fbbf24" fillOpacity={0.6} />
                  <Area type="monotone" dataKey="Surprise" stackId="1" stroke="#8b5cf6" fill="#a78bfa" fillOpacity={0.6} />
                  <Area type="monotone" dataKey="Anger" stackId="1" stroke="#ef4444" fill="#f87171" fillOpacity={0.6} />
                  <Area type="monotone" dataKey="Sadness" stackId="1" stroke="#3b82f6" fill="#60a5fa" fillOpacity={0.6} />
                  <Area type="monotone" dataKey="Neutral" stackId="1" stroke="#9ca3af" fill="#d1d5db" fillOpacity={0.4} />
                </AreaChart>
              </ResponsiveContainer>
            ) : (
              <div className="h-full flex items-center justify-center text-black/40 italic text-center px-4">
                Emotion analysis is not available for this project. <br />
                Try processing the video again to generate new data.
              </div>
            )}
          </div>
        </div>
      </div>

      {/* Back */}
      <div className="mt-auto pt-10 flex items-center gap-3 text-sm">
        <Link href={`/projects/${id}`} className="flex items-center gap-3">
          <div className="h-9 w-9 rounded-full border border-black/30 bg-white flex items-center justify-center">
            ←
          </div>
          <span className="uppercase tracking-widest">Back to Project</span>
        </Link>
      </div>
    </div>
  );
}