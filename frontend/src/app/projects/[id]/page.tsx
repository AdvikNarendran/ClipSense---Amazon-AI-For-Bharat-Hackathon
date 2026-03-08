'use client';

import Link from "next/link";
import { useEffect, useState } from "react";
import { useParams } from "next/navigation";
import {
  getProject,
  getProcessingStatus,
  processProject,
  getProjectVideoUrl,
  getTranscriptUrl,
  type Project,
} from "@/lib/api";

export default function ProjectDetailsPage() {
  const { id } = useParams<{ id: string }>();
  const [project, setProject] = useState<Project | null>(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [polling, setPolling] = useState(false);

  // Fetch project data
  useEffect(() => {
    let cancelled = false;

    async function load() {
      try {
        setLoading(true);
        const data = await getProject(id);
        if (!cancelled) {
          setProject(data);
          // If project is fresh (uploaded but not processing), kick it off!
          if (data.status === "uploaded") {
            processProject(id).catch(console.error);
            setProject(prev => prev ? { ...prev, status: "processing" } : prev);
            setPolling(true);
          } else if (data.status === "processing") {
            setPolling(true);
          }
        }
      } catch (e: unknown) {
        if (!cancelled) setError(e instanceof Error ? e.message : "Failed to load project");
      } finally {
        if (!cancelled) setLoading(false);
      }
    }

    load();
    return () => { cancelled = true; };
  }, [id]);

  // Poll for processing status
  useEffect(() => {
    if (!polling) return;

    const interval = setInterval(async () => {
      try {
        const status = await getProcessingStatus(id);

        // Update local project status and step even if not "done"
        setProject((prev) => prev ? {
          ...prev,
          status: status.status,
          currentStep: status.currentStep,
          clipCount: status.clipCount,
          error: status.error
        } : prev);

        if (status.status === "done" || status.status === "error") {
          setPolling(false);
          // Reload full project data to get new clips, etc.
          const data = await getProject(id);
          setProject(data);
        }
      } catch {
        // Ignore polling errors
      }
    }, 3000);

    return () => clearInterval(interval);
  }, [polling, id]);

  async function handleReprocess() {
    try {
      setError(null);
      await processProject(id);
      setPolling(true);
      setProject((prev) => prev ? { ...prev, status: "processing" } : prev);
    } catch (e: unknown) {
      setError(e instanceof Error ? e.message : "Failed to start processing");
    }
  }

  if (loading) {
    return (
      <div className="wf-panel p-10 text-center text-black/60 animate-pulse">
        Loading project…
      </div>
    );
  }

  if (error || !project) {
    return (
      <div className="wf-panel p-6">
        <div className="text-red-700 mb-2">{error || "Project not found"}</div>
        <Link className="underline" href="/projects">Back to Projects</Link>
      </div>
    );
  }

  const videoUrl = getProjectVideoUrl(project.id);

  return (
    <div className="min-h-[calc(100vh-200px)] flex flex-col">
      <h1 className="text-3xl font-medium mb-6">Project Details</h1>

      {/* Video Preview */}
      <div className="wf-panel p-6 mb-8">
        <div className="wf-panel p-6 bg-white">
          <div className="wf-panel p-6 flex items-center justify-center">
            <video
              src={videoUrl}
              controls
              className="w-full max-w-[740px] h-[260px] rounded-lg border border-black/10 bg-black object-cover"
            />
          </div>
        </div>
      </div>

      {/* Status Banner */}
      {project.status === "processing" && (
        <div className="wf-panel p-4 mb-6 text-center animate-pulse bg-yellow-50 border-yellow-200">
          <div className="mb-1">
            🧠 {project.currentStep || "AI is processing your video…"} This may take a few minutes.
          </div>
          <div className="text-sm text-black/60">
            📧 You will receive an email notification once processing is complete.
          </div>
        </div>
      )}

      {project.status === "error" && (
        <div className="wf-panel p-4 mb-6 bg-red-50 border border-red-200 rounded-lg">
          <div className="text-red-700 mb-2">Processing error: {project.error}</div>
          <button className="wf-view" onClick={handleReprocess}>
            Retry Processing
          </button>
        </div>
      )}

      {/* Stats Cards */}
      <div className="grid grid-cols-1 md:grid-cols-3 gap-6 mb-10">
        <div className="wf-stat">
          <div className="text-sm font-medium">No. Of Clips</div>
          <div className="mt-2 text-lg font-semibold">{project.clipCount}</div>
        </div>
        <div className="wf-stat">
          <div className="text-sm font-medium">Avg. Engagement</div>
          <div className="mt-2 text-lg font-semibold">
            {project.avgEngagement ? `${project.avgEngagement}/100` : "—"}
          </div>
        </div>
        <div className="wf-stat">
          <div className="text-sm font-medium">Status</div>
          <div className="mt-2 text-lg font-semibold truncate capitalize" title={project.currentStep || project.status}>
            {project.status === "processing" ? (project.currentStep || "Processing") : project.status}
          </div>
        </div>
      </div>

      {/* Action Buttons */}
      {project.status === "done" && project.clipCount > 0 && (
        <div className="flex flex-col items-center gap-4 mb-10">
          <Link href={`/projects/${id}/clips`} className="wf-cta w-[320px] text-center">
            View Clips
          </Link>
          <a
            href={getTranscriptUrl(id)}
            download
            className="text-sm font-medium text-black/60 hover:text-black flex items-center gap-2"
          >
            <span>📄 Download Transcript (.txt)</span>
          </a>
        </div>
      )}

      {project.status === "uploaded" && (
        <div className="flex justify-center mb-10">
          <button className="wf-cta w-[320px] text-center" onClick={handleReprocess}>
            🚀 Start AI Processing
          </button>
        </div>
      )}

      <div className="flex justify-center mb-6">
        <Link href={`/projects/${id}/analytics`} className="wf-view">Analytics</Link>
      </div>

      {/* Back */}
      <div className="mt-auto flex items-center gap-3 text-sm">
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