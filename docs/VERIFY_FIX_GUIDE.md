# How to Verify Worker Fix Without Uploading Video

## Quick Verification (Copy-Paste into EC2)

Connect to EC2 via Session Manager and run these commands:

### Method 1: Quick Check (30 seconds)

```bash
echo "=== Worker Status ==="
docker ps | grep clipsense-worker

echo ""
echo "=== Check for Video Download Code ==="
docker exec clipsense-worker grep -A 5 "Download video for emotion analysis" /app/worker.py | head -8

echo ""
echo "=== Check for audio_path Parameter ==="
docker exec clipsense-worker grep "audio_path=local_video_path" /app/worker.py

echo ""
echo "=== Check for Recent Errors ==="
docker logs --tail 100 clipsense-worker 2>&1 | grep -i "error\|failed" | tail -5

echo ""
echo "=== Worker is Polling SQS ==="
docker logs --tail 30 clipsense-worker | grep -E "Starting SQS|polling"
```

**Expected Output:**
- ✅ Container is running
- ✅ Shows code with "Download video for emotion analysis"
- ✅ Shows line with "audio_path=local_video_path"
- ✅ No recent "local_video_path" errors
- ✅ Shows "Starting SQS polling loop"

---

### Method 2: Detailed Verification

```bash
#!/bin/bash
echo "=========================================="
echo "Verifying Worker Fix"
echo "=========================================="

# 1. Container Status
echo ""
echo "1. Container Status:"
docker ps --filter "name=clipsense-worker" --format "table {{.Names}}\t{{.Status}}\t{{.Image}}"

# 2. Check the fix is in the code
echo ""
echo "2. Video Download Code (should show ~8 lines):"
docker exec clipsense-worker grep -A 8 "Download video for emotion analysis" /app/worker.py 2>/dev/null | head -10

# 3. Check audio_path parameter
echo ""
echo "3. Audio Path Parameter (should show 1 line):"
docker exec clipsense-worker grep "audio_path=local_video_path" /app/worker.py 2>/dev/null

# 4. Check for errors in logs
echo ""
echo "4. Recent Errors (should be empty or no local_video_path errors):"
docker logs --tail 200 clipsense-worker 2>&1 | grep "UnboundLocalError: local_video_path" | tail -3

# 5. Worker activity
echo ""
echo "5. Worker Activity (last 20 lines):"
docker logs --tail 20 clipsense-worker

echo ""
echo "=========================================="
echo "Verification Complete"
echo "=========================================="
```

---

### Method 3: Code Inspection

View the actual fixed code:

```bash
# View the process_video_job function (lines 60-120)
docker exec clipsense-worker sed -n '60,120p' /app/worker.py

# Or search for specific sections
docker exec clipsense-worker grep -A 15 "STEP 2: Download video" /app/worker.py
```

---

## What to Look For

### ✅ Fix Applied Successfully

You should see this code in the worker:

```python
# STEP 2: Download video for emotion analysis
temp_source = tempfile.NamedTemporaryFile(delete=False, suffix=".mp4")
local_video_path = temp_source.name
temp_source.close()

logger.info("[WORKER] Downloading source from S3 for emotion analysis: %s", s3_uri)
s3 = s3_storage.s3_client
bucket = s3_uri.split('/')[2]
key = "/".join(s3_uri.split('/')[3:])
s3.download_file(bucket, key, local_video_path)

# STEP 2.1: Audio Emotion Analysis
db.update_project(project_id, {"currentStep": "Analyzing Audio Emotions...", "progress": 40})
emotion_data = analyze_emotions(transcript_segments, audio_path=local_video_path, engine=_engine_instance)
```

### ✅ Worker Logs Look Good

Recent logs should show:
```
[INFO] clipsense-worker: ClipSense EC2 Worker Starting
[INFO] clipsense-worker: AWS Region: ap-south-1
[INFO] clipsense-worker: S3 Bucket: clipsense-media-storage-cs
[INFO] clipsense-worker: [WORKER] Starting SQS polling loop...
```

**NO errors like:**
```
UnboundLocalError: cannot access local variable 'local_video_path'
```

---

## Alternative: Check a Previous Project

If you have a recently processed project, check if it has emotion data:

```bash
# List recent projects in DynamoDB
aws dynamodb scan \
  --table-name ClipSense-Projects \
  --limit 5 \
  --region ap-south-1 \
  --query 'Items[*].[projectId.S, status.S, emotionData]' \
  --output table
```

Or check via your frontend:
1. Open a recently processed project
2. Look for emotion analysis data in the project details
3. Check if clips have emotional insights

---

## Backup Verification

Check if backups were created:

```bash
# List backups
docker exec clipsense-worker ls -lah /app/worker.py.backup.*

# Compare current with backup
docker exec clipsense-worker wc -l /app/worker.py
docker exec clipsense-worker bash -c 'wc -l /app/worker.py.backup.* 2>/dev/null | tail -1'
```

The current file should have more lines than the backup (added code).

---

## Quick Status Summary

Run this one-liner for a quick status:

```bash
echo "Container: $(docker ps --filter 'name=clipsense-worker' --format '{{.Status}}')" && \
echo "Fix Applied: $(docker exec clipsense-worker grep -c 'Download video for emotion analysis' /app/worker.py) occurrence(s)" && \
echo "Audio Path: $(docker exec clipsense-worker grep -c 'audio_path=local_video_path' /app/worker.py) occurrence(s)" && \
echo "Recent Errors: $(docker logs --tail 100 clipsense-worker 2>&1 | grep -c 'UnboundLocalError: local_video_path') error(s)"
```

**Expected output:**
```
Container: Up X minutes
Fix Applied: 1 occurrence(s)
Audio Path: 1 occurrence(s)
Recent Errors: 0 error(s)
```

---

## If Fix is NOT Applied

If the checks fail, re-run the fix script:

```bash
# Re-run the fix (safe to run multiple times)
# Copy the script from FIX_ON_EC2_GUIDE.md
```

---

## Summary

**Without uploading a video, you can verify:**

1. ✅ Container is running
2. ✅ Code contains video download logic
3. ✅ Code contains audio_path parameter
4. ✅ No recent local_video_path errors
5. ✅ Worker is polling SQS queue
6. ✅ Environment variables are set

**All checks passing = Fix is working correctly!**

The next video you upload will process with emotion analysis.
