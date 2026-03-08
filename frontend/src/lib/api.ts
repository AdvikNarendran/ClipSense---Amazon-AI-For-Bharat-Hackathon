/**
 * ClipSense API Client
 * Centralized API communication with the Flask backend.
 */

const API_BASE = process.env.NEXT_PUBLIC_API_URL || "http://localhost:5000";

const getTokenQuery = () => {
  const token = typeof window !== "undefined" ? localStorage.getItem("clipsense_token") : null;
  return token ? `?token=${token}` : "";
};

// ---------------------------------------------------------------------------
// Types
// ---------------------------------------------------------------------------

export type ProjectStatus = "uploaded" | "processing" | "done" | "error";

export type ClipMeta = {
  id: string;
  index: number;
  filename: string;
  startTime: number;
  endTime: number;
  viralScore: number;
  hookTitle: string;
  caption: string;
  summary: string;
  hashtags: string;
  downloadUrl: string;
  transcript?: string;
  emotions?: {
    joy: number;
    sadness: number;
    anger: number;
    surprise: number;
    neutral: number;
    intensity: number;
  };
};

export type Project = {
  id: string;
  title: string;
  filename: string;
  createdAt: string;
  duration: string | null;
  status: ProjectStatus;
  maxDuration: number;
  useSubs: boolean;
  clips: ClipMeta[];
  clipCount: number;
  avgEngagement: number;
  currentStep?: string;
  error: string | null;
  userId?: string;
};

export type ProcessingStatus = {
  status: ProjectStatus;
  currentStep: string;
  clipCount: number;
  progress: number;
  error: string | null;
};

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

async function apiFetch<T>(path: string, init: RequestInit = {}): Promise<T> {
  const url = `${API_BASE}${path}`;

  // Basic Auth Header
  const token = typeof window !== "undefined" ? localStorage.getItem("clipsense_token") : null;
  const headers = new Headers(init.headers || {});
  if (token) {
    headers.set("Authorization", `Bearer ${token}`);
  }

  const res = await fetch(url, { ...init, headers });

  if (!res.ok) {
    const data = await res.json().catch(() => ({}));
    throw new Error(data.message || data.error || `API ${res.status}: ${res.statusText}`);
  }

  const data = await res.json();

  // Helper to map projectId -> id for frontend consistency
  const mapId = (obj: any) => {
    if (obj && typeof obj === "object") {
      if (obj.projectId && !obj.id) obj.id = obj.projectId;
    }
    return obj;
  };

  const finalData = Array.isArray(data) ? data.map(mapId) : mapId(data);
  return finalData as T;
}

// ---------------------------------------------------------------------------
// Health
// ---------------------------------------------------------------------------

export async function checkHealth(): Promise<{ status: string }> {
  return apiFetch("/api/health");
}

// ---------------------------------------------------------------------------
// Upload
// ---------------------------------------------------------------------------

export async function uploadVideo(
  file: File,
  options: { maxDuration?: number; useSubs?: boolean; numClips?: number } = {},
  onProgress?: (pct: number) => void
): Promise<{ id: string; project: Project }> {
  try {
    // Step 1: Get presigned URL from backend
    const presignedResponse = await apiFetch<{
      projectId: string;
      s3Key: string;
      uploadUrl: string;
      uploadFields: Record<string, string>;
    }>("/api/upload/presigned-url", {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ filename: file.name }),
    });

    const { projectId, s3Key, uploadUrl, uploadFields } = presignedResponse;

    // Step 2: Upload directly to S3 using presigned POST
    await new Promise<void>((resolve, reject) => {
      const formData = new FormData();

      // Add all presigned fields first
      Object.entries(uploadFields).forEach(([key, value]) => {
        formData.append(key, value);
      });

      // Add the file last (important for S3)
      formData.append("file", file);

      const xhr = new XMLHttpRequest();
      xhr.open("POST", uploadUrl);

      xhr.upload.onprogress = (evt) => {
        if (evt.lengthComputable && onProgress) {
          onProgress(Math.round((evt.loaded / evt.total) * 100));
        }
      };

      xhr.onload = () => {
        if (xhr.status >= 200 && xhr.status < 300) {
          resolve();
        } else {
          reject(new Error(`S3 upload failed (${xhr.status})`));
        }
      };

      xhr.onerror = () => reject(new Error("Network error during S3 upload"));
      xhr.onabort = () => reject(new Error("Upload aborted"));

      xhr.send(formData);
    });

    // Step 3: Notify backend that upload is complete
    const result = await apiFetch<{ id: string; project: Project }>("/api/upload/complete", {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({
        projectId,
        filename: file.name,
        s3Key,
        maxDuration: options.maxDuration || 15,
        numClips: options.numClips || 3,
        useSubs: options.useSubs !== undefined ? options.useSubs : true,
      }),
    });

    return result;
  } catch (error) {
    // Fallback to old upload method for small files (<10MB) if presigned URL fails
    if (file.size < 10 * 1024 * 1024) {
      console.warn("Presigned upload failed, falling back to direct upload for small file");
      return uploadVideoLegacy(file, options, onProgress);
    }
    throw error;
  }
}


// ---------------------------------------------------------------------------
// Projects
// ---------------------------------------------------------------------------

export async function getProjects(): Promise<Project[]> {
  return apiFetch("/api/projects");
}

export async function getProject(id: string): Promise<Project> {
  return apiFetch(`/api/projects/${id}`);
}

// ---------------------------------------------------------------------------
// Processing
// ---------------------------------------------------------------------------

export async function processProject(id: string): Promise<{ message: string; status: string }> {
  return apiFetch(`/api/projects/${id}/process`, { method: "POST" });
}

export async function getProcessingStatus(id: string): Promise<ProcessingStatus> {
  return apiFetch(`/api/projects/${id}/status`);
}

export async function deleteProject(id: string): Promise<{ message: string; id: string }> {
  return apiFetch(`/api/projects/${id}`, { method: "DELETE" });
}

// ---------------------------------------------------------------------------
// Clips
// ---------------------------------------------------------------------------

export async function getClips(projectId: string): Promise<ClipMeta[]> {
  return apiFetch(`/api/projects/${projectId}/clips`);
}

export function getClipDownloadUrl(clipId: string): string {
  return `${API_BASE}/api/clips/${clipId}/download${getTokenQuery()}`;
}

export function getProjectVideoUrl(projectId: string): string {
  return `${API_BASE}/api/projects/${projectId}/video${getTokenQuery()}`;
}

export function getTranscriptUrl(projectId: string): string {
  return `${API_BASE}/api/projects/${projectId}/transcript${getTokenQuery()}`;
}
// ---------------------------------------------------------------------------
// Auth
// ---------------------------------------------------------------------------

export type User = {
  email: string;
  username: string;
  role: string;
};

export async function loginUser(identifier: string, password: string): Promise<{ token: string; user: User }> {
  return apiFetch("/api/auth/login", {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({ identifier, password }),
  });
}

export async function registerUser(email: string, password: string, username?: string): Promise<{ message: string }> {
  return apiFetch("/api/auth/register", {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({ email, password, username }),
  });
}

export async function verifyOtp(email: string, otp: string): Promise<{ message: string }> {
  return apiFetch("/api/auth/verify-otp", {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({ email, otp }),
  });
}

export async function getMe(): Promise<{ user: User }> {
  return apiFetch("/api/auth/me");
}

export async function updateProfile(data: { username: string }): Promise<{ message: string; username: string }> {
  return apiFetch("/api/auth/update-profile", {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify(data),
  });
}

export async function requestPasswordChange(): Promise<{ message: string }> {
  return apiFetch("/api/auth/request-password-change", {
    method: "POST",
  });
}

export async function confirmPasswordChange(otp: string, password: string): Promise<{ message: string }> {
  return apiFetch("/api/auth/confirm-password-change", {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({ otp, password }),
  });
}

export async function getUserStats(): Promise<{ projectCount: number; clipCount: number }> {
  return apiFetch("/api/auth/stats");
}

export async function deleteAccount(): Promise<{ message: string }> {
  return apiFetch("/api/auth/delete-account", {
    method: "DELETE",
  });
}

export async function forgotPassword(email: string): Promise<{ message: string }> {
  return apiFetch("/api/auth/forgot-password", {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({ email }),
  });
}

export async function resetPassword(email: string, otp: string, password: string): Promise<{ message: string }> {
  return apiFetch("/api/auth/reset-password", {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({ email, otp, password }),
  });
}

// ---------------------------------------------------------------------------
// Emotion & Attention Data
// ---------------------------------------------------------------------------

export type EmotionScore = {
  timestamp: number;
  end_time: number;
  joy: number;
  sadness: number;
  anger: number;
  surprise: number;
  neutral: number;
  intensity: number;
};

export type AttentionCurveData = {
  curve: { timestamp: number; score: number }[];
  peaks: { timestamp: number; score: number }[];
  avgAttention: number;
  peakMoments: number;
};

export async function getEmotionData(projectId: string): Promise<EmotionScore[]> {
  return apiFetch(`/api/projects/${projectId}/emotions`);
}

export async function getAttentionCurve(projectId: string): Promise<AttentionCurveData> {
  return apiFetch(`/api/projects/${projectId}/attention-curve`);
}

export async function getClipDetail(clipId: string): Promise<ClipMeta> {
  return apiFetch(`/api/clips/${clipId}/detail`);
}

// ---------------------------------------------------------------------------
// Export & Download
// ---------------------------------------------------------------------------

export function getExportUrl(projectId: string): string {
  return `${API_BASE}/api/projects/${projectId}/export${getTokenQuery()}`;
}

export function getDownloadAllUrl(projectId: string): string {
  return `${API_BASE}/api/projects/${projectId}/download-all${getTokenQuery()}`;
}

// ---------------------------------------------------------------------------
// Admin
// ---------------------------------------------------------------------------

export type AdminMetrics = {
  engineReady: boolean;
  dbReady: boolean;
  activeJobs: number;
  queueLength: number;
  totalProcessed: number;
  totalFailed: number;
  errorRate: number;
  avgProcessingTimeSec: number;
};

export async function getAdminMetrics(): Promise<AdminMetrics> {
  return apiFetch("/api/admin/metrics");
}

export type AdminUserStat = {
  email: string;
  username: string;
  createdAt: string;
  projectCount: number;
  clipCount: number;
  avgEngagement: number;
};

export async function getAdminUsers(): Promise<AdminUserStat[]> {
  return apiFetch("/api/admin/users");
}

export async function getAdminAllProjects(): Promise<Project[]> {
  return apiFetch("/api/admin/all-projects");
}
