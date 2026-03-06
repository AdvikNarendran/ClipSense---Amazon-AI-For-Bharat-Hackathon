'use client';

import Link from "next/link";
import { useEffect, useState } from "react";
import { getProjects, deleteProject, type Project } from "@/lib/api";
import { formatDate } from "@/lib/utils";

export default function ProjectsPage() {
  const [projects, setProjects] = useState<Project[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    let cancelled = false;

    async function load() {
      try {
        setLoading(true);
        const data = await getProjects();
        if (!cancelled) setProjects(data);
      } catch (e: unknown) {
        if (!cancelled) setError(e instanceof Error ? e.message : "Failed to load projects");
      } finally {
        if (!cancelled) setLoading(false);
      }
    }

    load();
    return () => { cancelled = true; };
  }, []);

  const handleDelete = async (id: string) => {
    if (!confirm("Are you sure you want to delete this project? This action cannot be undone.")) return;
    try {
      await deleteProject(id);
      setProjects((prev) => prev.filter((p) => p.id !== id));
    } catch (e) {
      alert(e instanceof Error ? e.message : "Failed to delete project");
    }
  };

  const statusBadge = (status: string) => {
    const colors: Record<string, string> = {
      uploaded: "bg-blue-100 text-blue-700",
      processing: "bg-yellow-100 text-yellow-700",
      done: "bg-green-100 text-green-700",
      error: "bg-red-100 text-red-700",
    };
    return (
      <span className={`inline-block px-2 py-0.5 rounded-full text-xs font-medium ${colors[status] || "bg-gray-100"}`}>
        {status}
      </span>
    );
  };

  return (
    <div>
      <div className="flex items-center justify-between mb-6">
        <h1 className="text-3xl font-medium">Projects</h1>

        <div className="flex items-center gap-3">
          <Link href="/upload" className="wf-view">New Upload</Link>
        </div>
      </div>

      {loading && (
        <div className="wf-panel p-10 text-center text-black/60 animate-pulse">
          Loading projects…
        </div>
      )}

      {error && (
        <div className="wf-panel p-6 text-red-700 bg-red-50 border border-red-200 rounded-lg">
          {error}
          <button className="ml-4 underline" onClick={() => window.location.reload()}>
            Retry
          </button>
        </div>
      )}

      {!loading && !error && projects.length === 0 && (
        <div className="wf-panel p-10 text-center">
          <div className="text-black/70 mb-4">No projects yet.</div>
          <Link href="/upload" className="wf-view">Upload your first video</Link>
        </div>
      )}

      {!loading && !error && projects.length > 0 && (
        <div className="wf-panel overflow-hidden">
          <div className="grid grid-cols-[1.3fr_0.7fr_0.5fr_0.6fr_0.6fr_0.5fr] items-center px-6 py-4 bg-black/10 text-sm font-medium">
            <div>Title</div>
            <div className="text-center">Status</div>
            <div className="text-center">Clips</div>
            <div className="text-center">Engagement</div>
            <div className="text-center">Created</div>
            <div className="text-center">Action</div>
          </div>

          {projects.map((p) => (
            <div
              key={p.id}
              className="grid grid-cols-[1.3fr_0.7fr_0.5fr_0.6fr_0.6fr_0.5fr] items-center px-6 py-4 border-t border-black/10"
              style={{ background: "rgb(var(--wf-row))" }}
            >
              <div className="font-semibold">{p.title}</div>
              <div className="text-center">{statusBadge(p.status)}</div>
              <div className="text-center">{p.clipCount}</div>
              <div className="text-center">
                {p.avgEngagement ? `${p.avgEngagement}/100` : "—"}
              </div>
              <div className="text-center">{formatDate(p.createdAt)}</div>
              <div className="flex justify-center gap-2">
                <Link href={`/projects/${p.id}`} className="wf-view" title="Open details">
                  view
                </Link>
                <button
                  onClick={() => handleDelete(p.id)}
                  className="px-2 py-1 text-xs font-medium text-red-600 hover:bg-red-50 rounded transition-colors"
                  title="Delete project"
                >
                  delete
                </button>
              </div>
            </div>
          ))}
        </div>
      )
      }
    </div >
  );
}