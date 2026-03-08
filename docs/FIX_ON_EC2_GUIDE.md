# Fix Emotion Analysis Directly on EC2

## Quick Fix (Recommended)

This will fix the emotion analysis issue directly on your running EC2 worker without rebuilding the Docker image.

### Step 1: Connect to EC2

Use AWS Session Manager (Instance Connect) since SSH port 22 is blocked:

```bash
# In AWS Console:
# EC2 → Instances → i-039398804f9156503 → Connect → Session Manager → Connect
```

### Step 2: Run the Fix Script

Copy and paste this entire script into your EC2 terminal:

```bash
#!/bin/bash
# Simple fix for emotion analysis

echo "=========================================="
echo "Fixing Emotion Analysis on EC2 Worker"
echo "=========================================="

echo "Step 1: Backup current worker.py"
docker exec clipsense-worker cp /app/worker.py /app/worker.py.backup.$(date +%s)
echo "✓ Backup created"

echo ""
echo "Step 2: Create and run fix script"
docker exec clipsense-worker bash << 'BASH_EOF'
cat > /tmp/fix_emotion.py << 'PYEOF'
import sys

# Read the current worker.py
with open("/app/worker.py", "r") as f:
    content = f.read()

# Check if fix is already applied
if "Download video for emotion analysis" in content:
    print("✓ Fix already applied!")
    sys.exit(0)

# Find the transcription update line
marker = 'db.update_project(project_id, {"transcription": transcript_segments, "progress": 30})'

if marker not in content:
    print("ERROR: Could not find transcription marker")
    sys.exit(1)

# The code to insert after transcription
new_code = '''db.update_project(project_id, {"transcription": transcript_segments, "progress": 30})

        # STEP 2: Download video for emotion analysis
        temp_source = tempfile.NamedTemporaryFile(delete=False, suffix=".mp4")
        local_video_path = temp_source.name
        temp_source.close()
        
        logger.info("[WORKER] Downloading source from S3 for emotion analysis: %s", s3_uri)
        s3 = s3_storage.s3_client
        bucket = s3_uri.split('/')[2]
        key = "/".join(s3_uri.split('/')[3:])
        s3.download_file(bucket, key, local_video_path)
        
        # STEP 2.1: Audio Emotion Analysis'''

# Replace the marker
content = content.replace(marker, new_code)

# Fix the emotion analysis call to include audio_path
content = content.replace(
    'emotion_data = analyze_emotions(transcript_segments, engine=_engine_instance)',
    'emotion_data = analyze_emotions(transcript_segments, audio_path=local_video_path, engine=_engine_instance)'
)

# Update rendering section to reuse downloaded video
old_rendering = '''# STEP 4: Rendering
        db.update_project(project_id, {"currentStep": "Rendering Clips...", "progress": 80})
        
        temp_source = tempfile.NamedTemporaryFile(delete=False, suffix=".mp4")
        local_video_path = temp_source.name
        temp_source.close()
        
        logger.info("[WORKER] Downloading source from S3: %s", s3_uri)
        s3 = s3_storage.s3_client
        bucket = s3_uri.split('/')[2]
        key = "/".join(s3_uri.split('/')[3:])
        s3.download_file(bucket, key, local_video_path)'''

new_rendering = '''# STEP 4: Rendering
        db.update_project(project_id, {"currentStep": "Rendering Clips...", "progress": 80})
        
        # Video already downloaded for emotion analysis, reuse it
        logger.info("[WORKER] Using already downloaded video for rendering")'''

if old_rendering in content:
    content = content.replace(old_rendering, new_rendering)

# Write the fixed content
with open("/app/worker.py", "w") as f:
    f.write(content)

print("✓ Worker code updated successfully")
PYEOF

python3 /tmp/fix_emotion.py
BASH_EOF

if [ $? -eq 0 ]; then
    echo "✓ Fix applied successfully"
else
    echo "✗ Fix failed"
    exit 1
fi

echo ""
echo "Step 3: Verify the changes"
echo "Checking for video download code..."
docker exec clipsense-worker grep -A 2 "Download video for emotion analysis" /app/worker.py | head -5

echo ""
echo "Checking for audio_path parameter..."
docker exec clipsense-worker grep "audio_path=local_video_path" /app/worker.py

echo ""
echo "Step 4: Restart worker container"
docker restart clipsense-worker

echo ""
echo "Step 5: Wait for container to start..."
sleep 5

echo ""
echo "Step 6: Check worker status"
docker ps | grep clipsense-worker

echo ""
echo "Step 7: View recent logs"
docker logs --tail 30 clipsense-worker

echo ""
echo "=========================================="
echo "✓ Emotion Analysis Fix Complete!"
echo "=========================================="
```

### Step 3: Verify the Fix

After running the script, you should see:
- ✓ Backup created
- ✓ Worker code updated successfully
- ✓ Fix applied successfully
- Container restarted
- Worker logs showing it's running

### Step 4: Test

1. Upload a test video through your frontend
2. Watch the processing logs:
   ```bash
   docker logs -f clipsense-worker
   ```
3. Look for:
   - "Downloading source from S3 for emotion analysis"
   - "Analyzing Audio Emotions..."
   - No "local_video_path" errors
   - Emotion data in the final project

---

## What This Fix Does

1. **Downloads video after transcription** - Creates a temporary file and downloads the video from S3
2. **Passes audio_path to emotion analyzer** - Fixes the `UnboundLocalError`
3. **Reuses downloaded video for rendering** - Avoids downloading twice
4. **Maintains all other functionality** - Transcription, visual analysis, clip generation all work as before

---

## Rollback (If Needed)

If something goes wrong, restore the backup:

```bash
# List backups
docker exec clipsense-worker ls -la /app/worker.py.backup.*

# Restore the most recent backup
docker exec clipsense-worker bash -c 'cp $(ls -t /app/worker.py.backup.* | head -1) /app/worker.py'

# Restart
docker restart clipsense-worker
```

---

## Alternative: Manual Fix

If the script doesn't work, you can manually edit the file:

```bash
# Enter the container
docker exec -it clipsense-worker bash

# Edit the file
vi /app/worker.py

# Find line ~85 (after transcription update)
# Add the video download code
# Update emotion_data line to include audio_path=local_video_path
# Update rendering section to reuse the video

# Exit and restart
exit
docker restart clipsense-worker
```

---

## Current Status

- ✅ Lambda deployed with subtitle endpoint
- ✅ Email credentials configured
- ⏳ Emotion analysis fix (run script above)

After this fix, all three issues will be resolved!
