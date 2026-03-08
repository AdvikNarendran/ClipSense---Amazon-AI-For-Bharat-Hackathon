# Script to apply the upload fix to frontend/src/lib/api.ts

Write-Host "Applying upload fix to frontend..." -ForegroundColor Cyan

$apiFile = "frontend/src/lib/api.ts"
$content = Get-Content $apiFile -Raw

# Define the new uploadVideo function
$newUploadFunction = @'
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

// Legacy upload method (for files <10MB or as fallback)
async function uploadVideoLegacy(
  file: File,
  options: { maxDuration?: number; useSubs?: boolean; numClips?: number } = {},
  onProgress?: (pct: number) => void
): Promise<{ id: string; project: Project }> {
  const formData = new FormData();
  formData.append("file", file);
  if (options.maxDuration) formData.append("maxDuration", String(options.maxDuration));
  if (options.useSubs !== undefined) formData.append("useSubs", String(options.useSubs));
  if (options.numClips) formData.append("numClips", String(options.numClips));

  // Use XHR for progress tracking
  return new Promise((resolve, reject) => {
    const xhr = new XMLHttpRequest();
    xhr.open("POST", `${API_BASE}/api/upload`);

    // Auth header for XHR
    const token = typeof window !== "undefined" ? localStorage.getItem("clipsense_token") : null;
    if (token) {
      xhr.setRequestHeader("Authorization", `Bearer ${token}`);
    }

    xhr.upload.onprogress = (evt) => {
      if (evt.lengthComputable && onProgress) {
        onProgress(Math.round((evt.loaded / evt.total) * 100));
      }
    };

    xhr.onload = () => {
      if (xhr.status >= 200 && xhr.status < 300) {
        try {
          resolve(JSON.parse(xhr.responseText));
        } catch {
          reject(new Error("Invalid JSON response"));
        }
      } else {
        reject(new Error(xhr.responseText || `Upload failed (${xhr.status})`));
      }
    };

    xhr.onerror = () => reject(new Error("Network error during upload"));
    xhr.onabort = () => reject(new Error("Upload aborted"));

    xhr.send(formData);
  });
}
'@

# Use regex to replace the uploadVideo function
$pattern = '(?s)export async function uploadVideo\([^{]*\{.*?\n\}\n\}'
$newContent = $content -replace $pattern, $newUploadFunction

# Write the updated content
Set-Content -Path $apiFile -Value $newContent -NoNewline

Write-Host "✅ Upload fix applied successfully!" -ForegroundColor Green
Write-Host "`nNext steps:" -ForegroundColor Yellow
Write-Host "1. git add frontend/src/lib/api.ts"
Write-Host "2. git commit -m 'Fix: Use S3 presigned URLs for video upload'"
Write-Host "3. git push origin main"
Write-Host "4. Wait for Amplify to redeploy (5-10 minutes)"
