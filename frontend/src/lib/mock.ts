export type Project = {
  id: string;
  title: string;
  updatedAt: string;   // display like 12/5/24
  duration: string;    // 00:08:02
  clips: number;
  avgEngagement: number; // 0..10
};

export type Clip = {
  id: string;
  projectId: string;
  timestamp: string;   // 02:14
  score: number;       // 0..10
};

export const projects: Project[] = [
  { id: "p1", title: "Video 1", updatedAt: "12/5/24", duration: "00:08:02", clips: 12, avgEngagement: 8.0 },
  { id: "p2", title: "Video 2", updatedAt: "12/5/24", duration: "00:08:02", clips: 12, avgEngagement: 8.3 },
  { id: "p3", title: "Video 3", updatedAt: "12/5/24", duration: "00:08:02", clips: 10, avgEngagement: 7.8 },
  { id: "p4", title: "Video 4", updatedAt: "12/5/24", duration: "00:08:02", clips: 10, avgEngagement: 8.6 },
  { id: "p5", title: "Video 5", updatedAt: "12/5/24", duration: "00:08:02", clips: 12, avgEngagement: 8.1 },
  { id: "p6", title: "Video 6", updatedAt: "12/5/24", duration: "00:08:02", clips: 10, avgEngagement: 8.9 },
];

export const clips: Clip[] = [
  { id: "c1", projectId: "p6", timestamp: "02:14", score: 8.9 },
  { id: "c2", projectId: "p6", timestamp: "04:28", score: 8.4 },
  { id: "c3", projectId: "p6", timestamp: "01:59", score: 8.0 },
  { id: "c4", projectId: "p6", timestamp: "05:56", score: 9.1 },
];

export function attentionCurveMock() {
  const pts = [];
  for (let t = 0; t <= 180; t += 5) {
    const v = Math.max(0, Math.min(100, 82 - t * 0.18 + 10 * Math.sin(t / 18)));
    pts.push({ t, v: Math.round(v) });
  }
  return pts;
}