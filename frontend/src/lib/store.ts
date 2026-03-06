export type StoredProject = {
  id: string;
  title: string;
  videoKey: string;
  createdAt: string;
  duration?: string;
};

const KEY = "clipsense_projects_v1";
const CLIPS_KEY = "clipsense_selected_clips_v1";

export function loadProjects(): StoredProject[] {
  if (typeof window === "undefined") return [];
  try { return JSON.parse(localStorage.getItem(KEY) || "[]"); }
  catch { return []; }
}

export function saveProject(p: StoredProject) {
  const list = loadProjects();
  localStorage.setItem(KEY, JSON.stringify([p, ...list]));
}

export function loadSelectedClips(projectId: string): Record<string, boolean> {
  if (typeof window === "undefined") return {};
  const all = JSON.parse(localStorage.getItem(CLIPS_KEY) || "{}");
  return all[projectId] || {};
}

export function toggleClip(projectId: string, clipId: string) {
  const all = JSON.parse(localStorage.getItem(CLIPS_KEY) || "{}");
  const cur = all[projectId] || {};
  cur[clipId] = !cur[clipId];
  all[projectId] = cur;
  localStorage.setItem(CLIPS_KEY, JSON.stringify(all));
}