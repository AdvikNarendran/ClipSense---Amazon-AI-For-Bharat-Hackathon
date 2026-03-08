#!/bin/bash
# Patch worker.py on EC2 to fix emotion analysis
# Run this script in EC2 Session Manager

echo "============================================================"
echo "Patching ClipSense Worker for Emotion Analysis Fix"
echo "============================================================"
echo ""

# Get the container ID
CONTAINER_ID=$(docker ps -q -f name=clipsense-worker)

if [ -z "$CONTAINER_ID" ]; then
    echo "❌ ERROR: clipsense-worker container not found"
    exit 1
fi

echo "✓ Found worker container: $CONTAINER_ID"
echo ""

# Create the patched worker.py content
echo "Creating patched worker.py..."

cat > /tmp/worker_patch.py << 'PATCH_EOF'
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
        db.update_project(project_id, {"emotionData": emotion_data, "progress": 50})
PATCH_EOF

# Copy current worker.py from container
echo "Backing up current worker.py..."
docker cp $CONTAINER_ID:/app/worker.py /tmp/worker_backup.py

# Apply the patch using sed
echo "Applying emotion analysis fix..."
docker exec $CONTAINER_ID bash -c "
# Backup original
cp /app/worker.py /app/worker.py.backup

# Apply fix: Download video earlier and pass audio_path to analyze_emotions
sed -i '
/# STEP 2: Audio Emotion Analysis/,/db.update_project(project_id, {\"emotionData\": emotion_data, \"progress\": 50})/ {
    /# STEP 2: Audio Emotion Analysis/c\
        # STEP 2: Download video for emotion analysis\
        temp_source = tempfile.NamedTemporaryFile(delete=False, suffix=\".mp4\")\
        local_video_path = temp_source.name\
        temp_source.close()\
        \
        logger.info(\"[WORKER] Downloading source from S3 for emotion analysis: %s\", s3_uri)\
        s3 = s3_storage.s3_client\
        bucket = s3_uri.split(\"/\")[2]\
        key = \"/\".join(s3_uri.split(\"/\")[3:])\
        s3.download_file(bucket, key, local_video_path)\
        \
        # STEP 2.1: Audio Emotion Analysis\
        db.update_project(project_id, {\"currentStep\": \"Analyzing Audio Emotions...\", \"progress\": 40})\
        emotion_data = analyze_emotions(transcript_segments, audio_path=local_video_path, engine=_engine_instance)\
        db.update_project(project_id, {\"emotionData\": emotion_data, \"progress\": 50})
    d
}
' /app/worker.py

# Remove duplicate video download in STEP 4
sed -i '
/# STEP 4: Rendering/,/s3.download_file(bucket, key, local_video_path)/ {
    /# Download video from S3/,/s3.download_file(bucket, key, local_video_path)/c\
        # Video already downloaded for emotion analysis, reuse it\
        logger.info(\"[WORKER] Using already downloaded video for rendering\")
}
' /app/worker.py
"

if [ $? -eq 0 ]; then
    echo "✓ Patch applied successfully"
    echo ""
    echo "Restarting worker container..."
    docker restart clipsense-worker
    
    echo ""
    echo "Waiting for worker to start..."
    sleep 5
    
    echo ""
    echo "Worker logs:"
    docker logs clipsense-worker --tail 20
    
    echo ""
    echo "============================================================"
    echo "✅ Worker patched and restarted successfully!"
    echo "============================================================"
    echo ""
    echo "The emotion analysis will now work correctly."
    echo "Process a new video to test the fix."
else
    echo ""
    echo "❌ ERROR: Patch failed"
    echo "Restoring backup..."
    docker exec $CONTAINER_ID cp /app/worker.py.backup /app/worker.py
    exit 1
fi
PATCH_EOF
