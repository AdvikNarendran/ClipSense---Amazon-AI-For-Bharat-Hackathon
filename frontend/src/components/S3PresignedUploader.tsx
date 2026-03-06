'use client';

import React, { useMemo, useRef, useState } from 'react';

type PresignResponse = {
  uploadUrl: string;
  objectKey: string;
  bucket?: string;
};

function formatBytes(n: number) {
  const units = ['B', 'KB', 'MB', 'GB'];
  let v = n;
  let i = 0;
  while (v >= 1024 && i < units.length - 1) {
    v /= 1024;
    i++;
  }
  return `${v.toFixed(i === 0 ? 0 : 1)} ${units[i]}`;
}

/**
 * ✅ AWS-Compatible upload
 * - Calls your REST API to get presigned PUT url
 * - Uploads directly to S3 via XHR to track progress
 * - Validates .mp4 + max size
 */
export default function S3PresignedUploader() {
  const MAX_BYTES = 2 * 1024 * 1024 * 1024; // 2GB example
  const [dragOver, setDragOver] = useState(false);
  const [file, setFile] = useState<File | null>(null);

  const [status, setStatus] = useState<
    'idle' | 'requesting-url' | 'uploading' | 'done' | 'error'
  >('idle');

  const [progressPct, setProgressPct] = useState(0);
  const [uploadedBytes, setUploadedBytes] = useState(0);
  const [errorMsg, setErrorMsg] = useState<string | null>(null);
  const [result, setResult] = useState<PresignResponse | null>(null);

  const inputRef = useRef<HTMLInputElement | null>(null);

  const canUpload = useMemo(() => !!file && status !== 'uploading', [file, status]);

function validate(f: File): string | null {
  const lower = f.name.toLowerCase();
  const isVideo = f.type.startsWith('video/');
  const isAudio = f.type.startsWith('audio/');
  const looksLikeMedia =
    isVideo ||
    isAudio ||
    /\.(mp4|mov|avi|mkv|webm|mp3|wav|m4a|aac|flac)$/i.test(lower);

  if (!looksLikeMedia) return 'Only audio and video files are allowed.';
  if (f.size > MAX_BYTES) return `Max file size is ${formatBytes(MAX_BYTES)}.`;
  return null;
}

  function pickFile(f: File) {
    const v = validate(f);
    if (v) {
      setErrorMsg(v);
      setFile(null);
      setStatus('error');
      return;
    }
    setErrorMsg(null);
    setStatus('idle');
    setResult(null);
    setProgressPct(0);
    setUploadedBytes(0);
    setFile(f);
  }

  async function getPresignedUrl(f: File): Promise<PresignResponse> {
    const res = await fetch('/api/presign-upload', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        filename: f.name,
        contentType: f.type || 'video/mp4',
      }),
    });

    if (!res.ok) {
      const t = await res.text().catch(() => '');
      throw new Error(t || `Presign API failed (${res.status})`);
    }
    return (await res.json()) as PresignResponse;
  }

  function uploadWithProgress(url: string, f: File): Promise<void> {
    return new Promise((resolve, reject) => {
      const xhr = new XMLHttpRequest();
      xhr.open('PUT', url, true);

      // Important: S3 presigned PUT usually expects the same content-type used when signing
      xhr.setRequestHeader('Content-Type', f.type || 'application/octet-stream');

      xhr.upload.onprogress = (evt) => {
        if (!evt.lengthComputable) return;
        setUploadedBytes(evt.loaded);
        setProgressPct(Math.round((evt.loaded / evt.total) * 100));
      };

      xhr.onload = () => {
        // S3 returns 200 or 204 typically
        if (xhr.status >= 200 && xhr.status < 300) resolve();
        else reject(new Error(`Upload failed (status ${xhr.status})`));
      };

      xhr.onerror = () => reject(new Error('Network error during upload.'));
      xhr.onabort = () => reject(new Error('Upload aborted.'));

      xhr.send(f);
    });
  }

  async function startUpload() {
    if (!file) return;

    try {
      setErrorMsg(null);
      setStatus('requesting-url');

      const presign = await getPresignedUrl(file);
      setResult(presign);

      setStatus('uploading');
      await uploadWithProgress(presign.uploadUrl, file);

      setStatus('done');
    } catch (e: any) {
      setStatus('error');
      setErrorMsg(e?.message || 'Upload failed.');
    }
  }

  return (
    <div className="w-full max-w-2xl mx-auto p-6">
      <div className="rounded-2xl border border-white/10 bg-black/40 backdrop-blur p-5">
        <div className="flex items-start justify-between gap-4">
          <div>
            <h2 className="text-xl font-bold text-white">Upload video</h2>
            <p className="text-white/70 text-sm">
              Drag & drop a .mp4. Upload goes directly to S3 using a presigned URL.
            </p>
          </div>

          <button
            onClick={() => inputRef.current?.click()}
            className="shrink-0 rounded-xl border border-white/15 text-white px-4 py-2 hover:bg-white/5"
          >
            Choose file
          </button>

          <input
            ref={inputRef}
            type="file"
            accept="video/mp4,.mp4"
            className="hidden"
            onChange={(e) => {
              const f = e.target.files?.[0];
              if (f) pickFile(f);
            }}
          />
        </div>

        <div
          className={[
            'mt-4 rounded-2xl border border-dashed p-6 transition',
            dragOver ? 'border-white/60 bg-white/5' : 'border-white/15 bg-white/[0.02]',
          ].join(' ')}
          onDragEnter={(e) => {
            e.preventDefault();
            e.stopPropagation();
            setDragOver(true);
          }}
          onDragOver={(e) => {
            e.preventDefault();
            e.stopPropagation();
            setDragOver(true);
          }}
          onDragLeave={(e) => {
            e.preventDefault();
            e.stopPropagation();
            setDragOver(false);
          }}
          onDrop={(e) => {
            e.preventDefault();
            e.stopPropagation();
            setDragOver(false);
            const f = e.dataTransfer.files?.[0];
            if (f) pickFile(f);
          }}
        >
          {!file ? (
            <div className="text-center">
              <div className="text-white font-semibold">Drop your .mp4 here</div>
              <div className="text-white/60 text-sm mt-1">
                Max size: {formatBytes(MAX_BYTES)}
              </div>
            </div>
          ) : (
            <div className="space-y-3">
              <div className="flex items-start justify-between gap-3">
                <div>
                  <div className="text-white font-semibold break-all">{file.name}</div>
                  <div className="text-white/60 text-sm">
                    {formatBytes(file.size)} • {file.type || 'video/mp4'}
                  </div>
                </div>

                <button
                  className="rounded-xl border border-white/15 text-white px-3 py-1.5 hover:bg-white/5"
                  onClick={() => {
                    setFile(null);
                    setResult(null);
                    setStatus('idle');
                    setProgressPct(0);
                    setUploadedBytes(0);
                    setErrorMsg(null);
                  }}
                  disabled={status === 'uploading'}
                >
                  Remove
                </button>
              </div>

              {/* Progress bar */}
              <div className="w-full rounded-xl bg-white/10 overflow-hidden">
                <div
                  className="h-2 bg-white/80"
                  style={{ width: `${progressPct}%` }}
                />
              </div>
              <div className="flex justify-between text-xs text-white/70">
                <span>
                  {status === 'uploading'
                    ? `Uploading… ${progressPct}%`
                    : status === 'done'
                    ? 'Upload complete'
                    : status === 'requesting-url'
                    ? 'Requesting URL…'
                    : 'Ready'}
                </span>
                <span>{uploadedBytes ? `${formatBytes(uploadedBytes)} uploaded` : ''}</span>
              </div>

              {errorMsg ? (
                <div className="rounded-xl border border-red-500/30 bg-red-500/10 p-3 text-red-100 text-sm">
                  {errorMsg}
                </div>
              ) : null}

              {result?.objectKey ? (
                <div className="rounded-xl border border-white/10 bg-white/5 p-3 text-white/80 text-xs break-all">
                  <div className="text-white font-semibold mb-1">Uploaded object key</div>
                  {result.objectKey}
                </div>
              ) : null}

              <button
                onClick={startUpload}
                disabled={!canUpload}
                className={[
                  'w-full rounded-xl py-2 font-semibold',
                  canUpload
                    ? 'bg-white text-black hover:opacity-90'
                    : 'bg-white/20 text-white/60 cursor-not-allowed',
                ].join(' ')}
              >
                {status === 'uploading' ? 'Uploading…' : 'Upload to S3'}
              </button>
            </div>
          )}
        </div>
      </div>
    </div>
  );
}