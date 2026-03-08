#!/bin/bash
# Simple fix for emotion analysis - replace the entire process_video_job function

echo "=========================================="
echo "Fixing Emotion Analysis on EC2 Worker"
echo "=========================================="

echo "Step 1: Backup current worker.py"
docker exec clipsense-worker cp /app/worker.py /app/worker.py.backup.$(date +%s)
echo "✓ Backup created"

echo ""
echo "Step 2: Create fixed process_video_job function"
docker exec clipsense-worker bash -c 'cat > /tmp/fix_emotion.py << '\''PYEOF'\''
import sys

# Read the current worker.py
with open("/app/worker.py", "r") as f:
    lines = f.readlines()

# Find where process_video_job function starts
start_idx = None
for i, line in enumerate(lines):
    if "def process_video_job(message_body):" in line:
        start_idx = i
        break

if start_idx is None:
    print("ERROR: Could not find process_video_job function")
    sys.exit(1)

# Find where the next function starts (poll_sqs_queue)
end_idx = None
for i in range(start_idx + 1, len(lines)):
    if lines[i].startswith("def ") or lines[i].startswith("# ---"):
        end_idx = i
        break

if end_idx is None:
    print("ERROR: Could not find end of process_video_job function")
    sys.exit(1)

# The fixed function
fixed_function = """def process_video_job(message_body):
    \"\"\"Process a single video job from SQS message.\"\"\"
    project_id = message_body.get("projectId")
    user_id = message_body.get("userId")
    s3_uri = message_body.get("s3Uri")
    s3_key = message_body.get("s3Key")
    settings = message_body.get("settings", {})
    
    max_duration = settings.get("maxDuration", 15)
    num_clips = settings.get("numClips", 3)
    use_subs = settings.get("useSubs", True)
    
    logger.info("[WORKER] Starting processing for project: %s", project_id)
    start_time = time.time()

    project = db.get_project(project_id)
    if not project:
        logger.error("[WORKER] Project %s not found", project_id)
        return

    try:
        # STEP 1: Transcribe via AWS
        db.update_project(project_id, {"status": "processing", "currentStep": "Transcribing...", "progress": 10})
        transcribe_result = _engine_instance.transcribe_video(s3_uri)
        transcript_segments = transcribe_result.get("segments", [])
        
        db.update_project(project_id, {"transcription": transcript_segments, "progress": 30})

        # STEP 2: Download video for emotion analysis
        temp_source = tempfile.NamedTemporaryFile(delete=False, suffix=".mp4")
        local_video_path = temp_source.name
        temp_source.close()
        
        logger.info("[WORKER] Downloading source from S3 for emotion analysis: %s", s3_uri)
        s3 = s3_storage.s3_client
        bucket = s3_uri.split(\'/\')[2]
        key = "/".join(s3_uri.split(\'/\')[3:])
        s3.download_file(bucket, key, local_video_path)
        
        # STEP 2.1: Audio Emotion Analysis
        db.update_project(project_id, {"currentStep": "Analyzing Audio Emotions...", "progress": 40})
        emotion_data = analyze_emotions(transcript_segments, audio_path=local_video_path, engine=_engine_instance)
        db.update_project(project_id, {"emotionData": emotion_data, "progress": 50})

        # STEP 2.5: Generate Attention Curve
        logger.info("[WORKER] Generating attention curve...")
        video_duration = float(transcript_segments[-1]["end"]) if transcript_segments else 0.0
        attention_curve = generate_attention_curve(emotion_data, video_duration=video_duration)
        db.update_project(project_id, {"attentionCurve": attention_curve, "progress": 55})

        # STEP 2.6: Visual Analysis (Rekognition)
        db.update_project(project_id, {"currentStep": "Analyzing Visuals (Rekognition)...", "progress": 58})
        visual_data = None
        if str(s3_uri).startswith("s3://"):
            visual_data = _engine_instance.analyze_visuals(s3_uri)
             
        # STEP 3: Bedrock Viral Analysis
        db.update_project(project_id, {"currentStep": "AI Selection (Bedrock)...", "progress": 60})
        clips_metadata = _engine_instance.analyze_transcription_with_timestamps(
            transcript_segments, 
            visual_data=visual_data,
            num_clips=num_clips,
            max_duration=max_duration
        )
        
        # STEP 3.5: Add emotional analysis detail for each clip
        for clip in clips_metadata:
            c_start = clip.get("start_time", 0)
            c_end = clip.get("end_time", 0)
            
            clip_emotions = [e for e in emotion_data if e["timestamp"] >= c_start and e["timestamp"] <= c_end]
            if clip_emotions:
                avg_intensity = sum(e.get("intensity", 0) for e in clip_emotions) / len(clip_emotions)
                emotions = ["joy", "sadness", "anger", "surprise", "neutral"]
                emotion_sums = {em: sum(e.get(em, 0) for e in clip_emotions) / len(clip_emotions) for em in emotions}
                primary = max(emotion_sums, key=emotion_sums.get)
                
                clip["emotional_analysis"] = {
                    "intensity_score": round(avg_intensity * 100, 1),
                    "primary_emotion": primary,
                    "insight": f"This clip has a {primary} tone with {round(avg_intensity * 100)}% engagement intensity."
                }
            else:
                clip["emotional_analysis"] = {"insight": "Emotional data not available for this segment."}
        
        # STEP 4: Rendering
        db.update_project(project_id, {"currentStep": "Rendering Clips...", "progress": 80})
        
        # Video already downloaded for emotion analysis, reuse it
        logger.info("[WORKER] Using already downloaded video for rendering")

        project_clips_dir = os.path.join("/tmp", f"clips_{project_id}")
        os.makedirs(project_clips_dir, exist_ok=True)

        generated_paths = process_video(
            local_video_path,
            clips_metadata,
            transcript_segments=transcript_segments,
            output_dir=project_clips_dir,
            use_subs=use_subs,
            max_clip_duration=max_duration,
            crop_mode="Letterbox",
        )

        # STEP 5: Upload clips to S3
        clips_list = []
        for idx, local_clip_path in enumerate(generated_paths):
            clip_filename = os.path.basename(local_clip_path)
            s3_clip_key = f"clips/{user_id}/{project_id}/{clip_filename}"
            s3_clip_uri = s3_storage.upload_file(local_clip_path, s3_clip_key)
            
            meta = clips_metadata[idx] if idx < len(clips_metadata) else {}
            clip_id = f"{project_id}_clip_{idx}"
            
            clips_list.append({
                "id": clip_id,
                "index": idx,
                "filename": clip_filename,
                "s3Key": s3_clip_key,
                "s3Uri": s3_clip_uri,
                "startTime": meta.get("start_time", 0),
                "endTime": meta.get("end_time", 0),
                "viralScore": meta.get("viral_score", 0),
                "hookTitle": meta.get("hook_title", ""),
                "caption": meta.get("caption", ""),
                "summary": meta.get("summary", ""),
                "hashtags": meta.get("hashtags", ""),
                "transcript": ""
            })

        # Cleanup /tmp
        try:
            time.sleep(1)
            if os.path.exists(local_video_path):
                os.remove(local_video_path)
            if os.path.exists(project_clips_dir):
                shutil.rmtree(project_clips_dir)
            logger.info("[WORKER] Cleanup successful for %s", project_id)
        except Exception as cleanup_err:
            logger.warning("[WORKER] Cleanup warning for %s: %s", project_id, cleanup_err)

        avg_engagement = round(sum(c["viralScore"] for c in clips_list) / len(clips_list), 1) if clips_list else 0

        db.update_project(project_id, {
            "clips": clips_list,
            "clipCount": len(clips_list),
            "avgEngagement": avg_engagement,
            "status": "done",
            "currentStep": "Completed",
            "progress": 100
        })

        elapsed = time.time() - start_time
        logger.info("[WORKER] ✅ Project %s DONE — %d clips in %.1fs", project_id, len(clips_list), elapsed)
        
        # Send email notification
        if user_id:
            send_processing_complete(user_id, project.get("title"), len(clips_list), avg_engagement)

    except Exception as e:
        logger.error("[WORKER] ❌ Project %s FAILED: %s", project_id, e, exc_info=True)
        db.update_project(project_id, {"status": "error", "error": str(e)})
        raise

"""

# Replace the function
new_lines = lines[:start_idx] + [fixed_function + "\n"] + lines[end_idx:]

# Write back
with open("/app/worker.py", "w") as f:
    f.writelines(new_lines)

print("✓ Function replaced successfully")
PYEOF
'

echo ""
echo "Step 3: Run the fix script"
docker exec clipsense-worker python3 /tmp/fix_emotion.py

if [ $? -eq 0 ]; then
    echo "✓ Fix applied successfully"
else
    echo "✗ Fix failed - restoring backup"
    docker exec clipsense-worker bash -c 'cp /app/worker.py.backup.* /app/worker.py 2>/dev/null || true'
    exit 1
fi

echo ""
echo "Step 4: Verify the changes"
echo "Checking for video download code..."
docker exec clipsense-worker grep -c "Download video for emotion analysis" /app/worker.py

echo ""
echo "Checking for audio_path parameter..."
docker exec clipsense-worker grep -c "audio_path=local_video_path" /app/worker.py

echo ""
echo "Step 5: Restart worker container"
docker restart clipsense-worker

echo ""
echo "Step 6: Wait for container to start..."
sleep 5

echo ""
echo "Step 7: Check worker status"
docker ps | grep clipsense-worker

echo ""
echo "Step 8: View recent logs"
docker logs --tail 30 clipsense-worker

echo ""
echo "=========================================="
echo "✓ Emotion Analysis Fix Complete!"
echo "=========================================="
echo ""
echo "Next steps:"
echo "1. Upload a test video"
echo "2. Check that emotion data appears in the project"
echo "3. Verify no 'local_video_path' errors in logs"
echo ""
echo "If issues persist, backups are available at:"
echo "  /app/worker.py.backup.*"
