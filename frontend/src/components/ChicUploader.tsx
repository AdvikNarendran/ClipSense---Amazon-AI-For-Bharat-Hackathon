'use client';

import { useRef, useState } from "react";
import { useRouter } from "next/navigation";
import { saveProject } from "@/lib/store";
import { idbPutBlob } from "@/lib/idb";

function formatBytes(n: number) {
  const units = ["B", "KB", "MB", "GB"];
  let v = n;
  let i = 0;
  while (v >= 1024 && i < units.length - 1) { v /= 1024; i++; }
  return `${v.toFixed(i === 0 ? 0 : 1)} ${units[i]}`;
}

export default function ChicUploader() {
  const router = useRouter();
  const inputRef = useRef<HTMLInputElement | null>(null);

  const [drag, setDrag] = useState(false);
  const [file, setFile] = useState<File | null>(null);
  const [status, setStatus] = useState<"idle" | "uploading" | "done" | "error">("idle");
  const [pct, setPct] = useState(0);
  const [err, setErr] = useState<string | null>(null);

  const MAX = 800 * 1024 * 1024; // 800MB for browser comfort (you can increase)

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
      setErr(`Max size for local demo is ${formatBytes(MAX)}.`);
      setFile(null);
      return;
    }

    setFile(f);
  }

  async function start() {
    if (!file) return;

    try {
      setErr(null);
      setStatus("uploading");

      // Simulate upload progress (since we’re not uploading anywhere yet)
      setPct(0);
      await new Promise<void>((resolve) => {
        let p = 0;
        const t = setInterval(() => {
          p += Math.max(2, Math.round(10 * Math.random()));
          if (p >= 100) {
            clearInterval(t);
            setPct(100);
            resolve();
          } else {
            setPct(p);
          }
        }, 120);
      });

      // Save the actual video blob locally (IndexedDB)
      const id = "p_" + Math.random().toString(16).slice(2);
      const videoKey = `video_${id}`;
      await idbPutBlob(videoKey, file);

      // Save project metadata
      saveProject({
        id,
        title: file.name.replace(/\.mp4$/i, ""),
        videoKey,
        createdAt: new Date().toISOString(),
        duration: "—",
      });

      setStatus("done");
      router.push(`/projects/${id}`);
    }  catch (e: unknown) {
      const message = e instanceof Error ? e.message : "Upload failed";
      setStatus("error");
      setErr(message);
    }
}

return (
  <div className="cs-card p-6">
    <div className="cs-card-soft p-8">
      <div
        className={[
          "rounded-[18px] border border-black/10 bg-white/70 p-10 text-center transition",
          drag ? "ring-4 ring-[rgba(166,134,83,0.25)]" : ""
        ].join(" ")}
        onDragEnter={(e) => { e.preventDefault(); setDrag(true); }}
        onDragOver={(e) => { e.preventDefault(); setDrag(true); }}
        onDragLeave={() => setDrag(false)}
        onDrop={(e) => {
          e.preventDefault();
          setDrag(false);
          const f = e.dataTransfer.files?.[0];
          if (f) pick(f);
        }}
      >
        <div className="text-2xl font-light tracking-wide">Drag and Drop Files</div>
        <div className="text-sm text-black/60 mt-2">
          Supported: common video &amp; audio formats (mp4, mov, avi, mkv, webm, mp3, wav, m4a, aac, flac)
        </div>

        <input
          ref={inputRef}
          className="hidden"
          type="file"
          accept="video/*,audio/*"
          onChange={(e) => {
            const f = e.target.files?.[0];
            if (f) pick(f);
          }}
        />

        <div className="mt-6 flex flex-col md:flex-row items-center justify-center gap-3">
          <button className="cs-btn cs-btn-gold" onClick={() => inputRef.current?.click()}>
            Choose File
          </button>

          <button
            className="cs-btn cs-btn-green"
            disabled={!file || status === "uploading"}
            onClick={start}
            style={{ opacity: !file ? 0.6 : 1 }}
          >
            {status === "uploading" ? `Uploading ${pct}%` : "Upload"}
          </button>
        </div>

        {file && (
          <div className="mt-5 text-sm text-black/70">
            <div className="font-semibold">{file.name}</div>
            <div className="text-black/50">{formatBytes(file.size)}</div>

            <div className="mt-3 h-2 rounded-full bg-black/10 overflow-hidden">
              <div
                className="h-full"
                style={{
                  width: `${pct}%`,
                  background: "rgb(var(--cs-gold))",
                  transition: "width 120ms linear"
                }}
              />
            </div>
          </div>
        )}

        {err && (
          <div className="mt-4 rounded-xl border border-red-500/30 bg-red-500/10 p-3 text-sm text-red-800">
            {err}
          </div>
        )}

        <div className="text-xs text-black/50 mt-4">
          Local demo mode: video stored in your browser (IndexedDB).
        </div>
      </div>
    </div>
  </div>
);
}