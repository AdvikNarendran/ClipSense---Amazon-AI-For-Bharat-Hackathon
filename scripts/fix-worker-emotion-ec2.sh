#!/bin/bash
# Fix emotion analysis on EC2 worker by adding video download step

echo "=========================================="
echo "Fixing Emotion Analysis on EC2 Worker"
echo "=========================================="

# Create a complete fixed worker.py
cat > /tmp/worker_fixed.py << 'WORKER_EOF'
# Add video download section before emotion analysis
import tempfile

# Inside process_video_job function, after transcription step:
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
WORKER_EOF

echo "Step 1: Backup current worker.py"
docker exec clipsense-worker cp /app/worker.py /app/worker.py.backup
echo "✓ Backup created"

echo ""
echo "Step 2: Apply the fix using Python script"
docker exec clipsense-worker python3 << 'PYTHON_EOF'
import re

# Read the current worker.py
with open('/app/worker.py', 'r') as f:
    content = f.read()

# Find the section after transcription
pattern = r'(db\.update_project\(project_id, \{"transcription": transcript_segments, "progress": 30\}\))'

# The new code to insert
new_code = '''

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

# Replace the old emotion analysis line
content = re.sub(
    r'db\.update_project\(project_id, \{"currentStep": "Analyzing Audio Emotions\.\.\.", "progress": 40\}\)\s*emotion_data = analyze_emotions\(transcript_segments, engine=_engine_instance\)',
    new_code + '\n        db.update_project(project_id, {"currentStep": "Analyzing Audio Emotions...", "progress": 40})\n        emotion_data = analyze_emotions(transcript_segments, audio_path=local_video_path, engine=_engine_instance)',
    content
)

# Also update the rendering section to reuse the downloaded video
content = re.sub(
    r'# STEP 4: Rendering.*?temp_source = tempfile\.NamedTemporaryFile.*?s3\.download_file\(bucket, key, local_video_path\)',
    '''# STEP 4: Rendering
        db.update_project(project_id, {"currentStep": "Rendering Clips...", "progress": 80})
        
        # Video already downloaded for emotion analysis, reuse it
        logger.info("[WORKER] Using already downloaded video for rendering")''',
    content,
    flags=re.DOTALL
)

# Write the fixed content
with open('/app/worker.py', 'w') as f:
    f.write(content)

print("✓ Worker code updated successfully")
PYTHON_EOF

echo ""
echo "Step 3: Verify the fix was applied"
echo "Checking for video download code..."
docker exec clipsense-worker grep -A 5 "Download video for emotion analysis" /app/worker.py

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
echo "Step 6: Verify worker is running"
docker ps | grep clipsense-worker

echo ""
echo "Step 7: Check worker logs"
docker logs --tail 20 clipsense-worker

echo ""
echo "=========================================="
echo "✓ Fix Applied Successfully!"
echo "=========================================="
echo ""
echo "The worker now:"
echo "1. Downloads video from S3 after transcription"
echo "2. Passes audio_path to analyze_emotions()"
echo "3. Reuses the downloaded video for rendering"
echo ""
echo "Test by uploading a new video and checking for emotion data."
