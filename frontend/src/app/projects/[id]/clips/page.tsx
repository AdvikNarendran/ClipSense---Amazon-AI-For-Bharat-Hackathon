'use client';

import Link from "next/link";
import { useParams } from "next/navigation";
import { useEffect, useState } from "react";
import {
  getClips, getClipDownloadUrl, getExportUrl, getDownloadAllUrl,
  type ClipMeta
} from "@/lib/api";

export default function ClipsPage() {
  const { id } = useParams<{ id: string }>();
  const [clips, setClips] = useState<ClipMeta[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [selected, setSelected] = useState<Record<string, boolean>>({});

  useEffect(() => {
    let cancelled = false;

    async function load() {
      try {
        setLoading(true);
        const data = await getClips(id);
        if (!cancelled) setClips(data);
      } catch (e: unknown) {
        if (!cancelled) setError(e instanceof Error ? e.message : "Failed to load clips");
      } finally {
        if (!cancelled) setLoading(false);
      }
    }

    load();
    return () => { cancelled = true; };
  }, [id]);

  function toggleSelect(clipId: string) {
    setSelected((prev) => ({ ...prev, [clipId]: !prev[clipId] }));
  }

  function formatTime(seconds: number): string {
    const m = Math.floor(seconds / 60);
    const s = Math.floor(seconds % 60);
    return `${String(m).padStart(2, "0")}:${String(s).padStart(2, "0")}`;
  }

  if (loading) {
    return (
      <div className="wf-panel p-10 text-center text-black/60 animate-pulse">
        Loading clips…
      </div>
    );
  }

  if (error) {
    return (
      <div className="wf-panel p-6">
        <div className="text-red-700 mb-2">{error}</div>
        <Link className="underline" href={`/projects/${id}`}>Back to Project</Link>
      </div>
    );
  }

  return (
    <div className="min-h-[calc(100vh-200px)] flex flex-col">
      <div className="flex flex-col md:flex-row md:items-center justify-between gap-4 mb-8">
        <h1 className="text-3xl font-medium">Clips Gallery</h1>

        {clips.length > 0 && (
          <div className="flex items-center gap-3">
            <a
              href={getExportUrl(id)}
              className="px-4 py-2 border border-black/20 rounded-xl text-sm hover:bg-black/5 transition-colors"
            >
              Export JSON
            </a>
            <a
              href={getDownloadAllUrl(id)}
              className="px-4 py-2 bg-black text-white rounded-xl text-sm hover:opacity-80 transition-opacity"
            >
              Download All (ZIP)
            </a>
          </div>
        )}
      </div>

      {clips.length === 0 ? (
        <div className="wf-panel p-10 text-center text-black/70">
          No clips generated yet. Go back and process the video first.
        </div>
      ) : (
        <div className="wf-panel p-6">
          <div className="grid grid-cols-1 md:grid-cols-2 gap-8">
            {clips.map((c) => {
              const active = !!selected[c.id];
              const downloadUrl = getClipDownloadUrl(c.id);

              return (
                <div key={c.id} className="wf-panel p-6 bg-white border border-black/5">
                  {/* Video preview */}
                  <video
                    src={downloadUrl}
                    controls
                    className="w-full h-52 rounded-xl bg-black object-cover shadow-lg"
                  />

                  {/* Metadata */}
                  <div className="mt-5 space-y-3">
                    <div className="flex items-start justify-between">
                      <div className="flex-1 pr-4">
                        <h3 className="font-bold text-lg leading-tight uppercase tracking-tight">
                          {c.hookTitle || `Clip #${c.index + 1}`}
                        </h3>
                        <p className="text-sm text-black/50 mt-1">
                          {formatTime(c.startTime)} — {formatTime(c.endTime)}
                        </p>
                      </div>
                      <div className="bg-orange-50 px-3 py-1 rounded-full border border-orange-200">
                        <span className="font-black text-orange-600 text-sm">
                          {c.viralScore}
                        </span>
                        <span className="text-orange-400 text-[10px] ml-0.5 uppercase">VIRAL</span>
                      </div>
                    </div>

                    {c.caption && (
                      <p className="text-sm text-black/70 leading-relaxed italic">
                        "{c.caption}"
                      </p>
                    )}

                    {/* Clip Transcript */}
                    {c.transcript && (
                      <div className="space-y-2">
                        <div className="text-[10px] font-bold uppercase tracking-widest text-black/40">Clip Transcript</div>
                        <div className="text-sm text-black/80 bg-black/5 p-4 rounded-xl border border-black/5 max-h-[120px] overflow-y-auto leading-relaxed">
                          {c.transcript}
                        </div>
                      </div>
                    )}

                    {/* Emotional Analysis */}
                    {c.emotions && (
                      <div className="space-y-3 pt-2">
                        <div className="text-[10px] font-bold uppercase tracking-widest text-black/40">Emotional Analysis</div>
                        <div className="grid grid-cols-3 gap-2">
                          {Object.entries(c.emotions).filter(([k]) => k !== 'intensity').map(([emotion, value]) => (
                            <div key={emotion} className="bg-black/[0.03] p-2 rounded-lg border border-black/5">
                              <div className="text-[10px] uppercase text-black/40 font-medium">{emotion}</div>
                              <div className="text-sm font-bold">{(value * 100).toFixed(0)}%</div>
                            </div>
                          ))}
                          <div className="bg-orange-50 p-2 rounded-lg border border-orange-100">
                            <div className="text-[10px] uppercase text-orange-400 font-medium">Intensity</div>
                            <div className="text-sm font-bold text-orange-600">{(c.emotions.intensity * 100).toFixed(0)}%</div>
                          </div>
                        </div>
                      </div>
                    )}

                    <div className="text-xs text-black/60 bg-black/5 p-3 rounded-lg border border-black/5">
                      <div className="text-[10px] font-bold uppercase tracking-widest text-black/30 mb-1">AI Summary</div>
                      {c.summary}
                    </div>

                    {c.hashtags && (
                      <div className="text-xs font-semibold text-orange-500 uppercase tracking-wider">
                        {c.hashtags}
                      </div>
                    )}
                  </div>

                  {/* Actions */}
                  <div className="grid grid-cols-2 gap-3 mt-6">
                    <a
                      href={downloadUrl}
                      download
                      className="wf-view py-3 text-center border-black/10"
                    >
                      ⬇ Download MP4
                    </a>
                    <button
                      className="wf-view py-3 border-black/10"
                      onClick={() => toggleSelect(c.id)}
                      style={{
                        background: active ? "#F59E0B" : undefined,
                        borderColor: active ? "#F59E0B" : undefined,
                        color: active ? "white" : undefined,
                      }}
                    >
                      {active ? "✓ Selected" : "Select Clip"}
                    </button>
                  </div>
                </div>
              );
            })}
          </div>
        </div>
      )}

      {/* Back */}
      <div className="mt-10 pt-10 flex items-center gap-3 text-sm">
        <Link href={`/projects/${id}`} className="flex items-center gap-3 group">
          <div className="h-10 w-10 rounded-full border border-black/20 bg-white flex items-center justify-center group-hover:bg-black group-hover:text-white transition-all">
            ←
          </div>
          <span className="uppercase tracking-widest font-bold">Back to Project Overview</span>
        </Link>
      </div>
    </div>
  );
}