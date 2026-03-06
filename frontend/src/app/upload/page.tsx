'use client';

import { useRef, useState } from "react";
import { useRouter } from "next/navigation";
import { uploadVideo, processProject } from "@/lib/api";
import { formatBytes } from "@/lib/utils";

export default function UploadPage() {
  const router = useRouter();
  const inputRef = useRef<HTMLInputElement | null>(null);

  const [file, setFile] = useState<File | null>(null);
  const [pct, setPct] = useState(0);
  const [err, setErr] = useState<string | null>(null);
  const [status, setStatus] = useState<"idle" | "uploading" | "processing">("idle");

  // Settings
  const [maxDuration, setMaxDuration] = useState(15);
  const [useSubs, setUseSubs] = useState(true);
  const [numClips, setNumClips] = useState(3);

  const MAX = 800 * 1024 * 1024;

  function pick(f: File) {
    setErr(null);
    setPct(0);

    const lower = f.name.toLowerCase();
    const isVideo = f.type.startsWith("video/");
    const isAudio = f.type.startsWith("audio/");
    const looksLikeMedia =
      isVideo ||
      isAudio ||
      /\.(mp4|mov|avi|mkv|webm|mp3|wav|m4a|aac|flac)$/i.test(lower);

    if (!looksLikeMedia) {
      setErr("Only audio and video files are supported.");
      setFile(null);
      return;
    }

    if (f.size > MAX) {
      setErr(`Max ${formatBytes(MAX)} file size.`);
      setFile(null);
      return;
    }

    setFile(f);
  }

  async function startUpload() {
    if (!file) return;
    try {
      setStatus("uploading");
      setErr(null);
      setPct(0);

      // Upload to backend
      const { id } = await uploadVideo(
        file,
        { maxDuration, useSubs, numClips },
        (progress) => setPct(progress)
      );

      // Navigate to project page immediately
      // The project details page will handle starting the processing if needed
      router.push(`/projects/${id}`);
    } catch (e: unknown) {
      setErr(e instanceof Error ? e.message : "Upload failed");
      setStatus("idle");
    }
  }

  return (
    <div>
      <h1 className="text-3xl font-medium mb-6">Upload</h1>

      <div className="wf-panel p-6">
        <div className="wf-panel p-6 bg-white">
          <div
            className="rounded-[18px] border border-black/10 bg-white/70 p-8 text-center transition"
            onDragOver={(e) => e.preventDefault()}
            onDrop={(e) => {
              e.preventDefault();
              const f = e.dataTransfer.files?.[0];
              if (f) pick(f);
            }}
          >
            <div className="text-lg font-semibold">Drag and Drop Files</div>
            <div className="text-sm text-black/60 mt-1">
              Supported: common video &amp; audio (mp4, mov, avi, mkv, webm, mp3, wav, m4a, aac, flac)
            </div>

            <input
              ref={inputRef}
              type="file"
              accept="video/*,audio/*"
              className="hidden"
              onChange={(e) => {
                const f = e.target.files?.[0];
                if (f) pick(f);
              }}
            />

            {/* Settings */}
            <div className="mt-6 flex flex-wrap items-center justify-center gap-4 text-sm text-black/70">
              <label className="flex items-center gap-2">
                Max clip duration:
                <select
                  className="wf-search w-auto py-1 px-3"
                  value={maxDuration}
                  onChange={(e) => setMaxDuration(Number(e.target.value))}
                >
                  {[10, 15, 20, 30, 45, 60].map((d) => (
                    <option key={d} value={d}>{d}s</option>
                  ))}
                </select>
              </label>
              <label className="flex items-center gap-2">
                <input
                  type="checkbox"
                  checked={useSubs}
                  onChange={(e) => setUseSubs(e.target.checked)}
                />
                Embed subtitles
              </label>
              <label className="flex items-center gap-2">
                Number of Reels:
                <select
                  className="wf-search w-auto py-1 px-3"
                  value={numClips}
                  onChange={(e) => setNumClips(Number(e.target.value))}
                >
                  {[1, 2, 3, 4, 5, 8, 10].map((n) => (
                    <option key={n} value={n}>{n}</option>
                  ))}
                </select>
              </label>
            </div>

            <div className="mt-5 flex items-center justify-center gap-3">
              <button className="wf-view" onClick={() => inputRef.current?.click()}>
                Choose File
              </button>
              <button
                className="wf-view"
                onClick={startUpload}
                disabled={!file || status !== "idle"}
                style={{ opacity: !file || status !== "idle" ? 0.6 : 1 }}
              >
                {status === "uploading"
                  ? `Uploading ${pct}%`
                  : status === "processing"
                    ? "Processing…"
                    : "Upload & Process"}
              </button>
            </div>

            {file && (
              <div className="mt-4 text-sm">
                <div className="font-semibold">{file.name}</div>
                <div className="text-black/60">{formatBytes(file.size)}</div>
                <div className="mt-3 h-2 rounded-full bg-black/10 overflow-hidden">
                  <div
                    className="h-full transition-all duration-150"
                    style={{
                      width: `${pct}%`,
                      background: "rgb(var(--cs-gold))",
                    }}
                  />
                </div>
              </div>
            )}

            {err && (
              <div className="mt-4 text-sm text-red-700 bg-red-100 border border-red-200 rounded-lg p-3">
                {err}
              </div>
            )}

            {status === "processing" && (
              <div className="mt-4 text-sm text-black/70 animate-pulse">
                🧠 AI is analyzing your video… This may take a minute.
              </div>
            )}
          </div>
        </div>
      </div>
    </div>
  );
}