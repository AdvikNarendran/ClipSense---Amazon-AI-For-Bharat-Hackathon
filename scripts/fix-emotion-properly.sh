#!/bin/bash
# Fix the emotion analysis issue properly

echo "=== Fixing Emotion Analysis Bug ==="

# The issue: local_video_path is only defined AFTER transcription when we download for emotion analysis
# But our sed command put it in the wrong place

# Revert the bad fix first
docker exec clipsense-worker bash -c 'sed -i "s/emotion_data = analyze_emotions(transcript_segments, audio_path=local_video_path, engine=_engine_instance)/emotion_data = analyze_emotions(transcript_segments, engine=_engine_instance)/" /app/worker.py'

# Now apply the correct fix - we need to download the video BEFORE emotion analysis
docker exec clipsense-worker bash -c 'cat > /tmp/fix_worker.py << '\''EOF'\''
import sys

# Read the file
with open("/app/worker.py", "r") as f:
    content = f.read()

# Find the section after transcription and before emotion analysis
# We need to add video download code here

old_code = """        db.update_project(project_id, {\"transcription\": transcript_segments, \"progress\": 30})

        # STEP 2: Audio Emotion Analysis
        db.update_project(project_id, {\"currentStep\": \"Analyzing Audio Emotions...\", \"progress\": 40})
        emotion_data = analyze_emotions(transcript_segments, engine=_engine_instance)"""

new_code = """        db.update_project(project_id, {\"transcription\": transcript_segments, \"progress\": 30})

        # STEP 2: Download video for emotion analysis
        temp_source = tempfile.NamedTemporaryFile(delete=False, suffix=\".mp4\")
        local_video_path = temp_source.name
        temp_source.close()
        
        logger.info(\"[WORKER] Downloading source from S3 for emotion analysis: %s\", s3_uri)
        s3 = s3_storage.s3_client
        bucket = s3_uri.split(\"/\")[2]
        key = \"/\".join(s3_uri.split(\"/\")[3:])
        s3.download_file(bucket, key, local_video_path)
        
        # STEP 2.1: Audio Emotion Analysis
        db.update_project(project_id, {\"currentStep\": \"Analyzing Audio Emotions...\", \"progress\": 40})
        emotion_data = analyze_emotions(transcript_segments, audio_path=local_video_path, engine=_engine_instance)"""

content = content.replace(old_code, new_code)

# Write back
with open("/app/worker.py", "w") as f:
    f.write(content)

print("Fixed!")
EOF
python3 /tmp/fix_worker.py'

echo ""
echo "=== Restarting Container ==="
docker restart clipsense-worker

echo ""
echo "=== Verifying Fix ==="
sleep 3
docker exec clipsense-worker grep -A 5 "Download video for emotion analysis" /app/worker.py

echo ""
echo "✅ Fix applied! The worker will now download the video before emotion analysis."
