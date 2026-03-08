#!/bin/bash
# Simple fix for emotion analysis on EC2
# Run this in EC2 Session Manager

echo "============================================================"
echo "Fixing Emotion Analysis in Worker Container"
echo "============================================================"
echo ""

# Install nano in container if not present
docker exec clipsense-worker bash -c "apt-get update -qq && apt-get install -y -qq nano 2>/dev/null || true"

echo "Opening worker.py for editing..."
echo ""
echo "INSTRUCTIONS:"
echo "1. Find line ~95: emotion_data = analyze_emotions(transcript_segments, engine=_engine_instance)"
echo "2. Change it to: emotion_data = analyze_emotions(transcript_segments, audio_path=local_video_path, engine=_engine_instance)"
echo "3. Move the video download code (lines ~120-130) to BEFORE the emotion analysis (around line 90)"
echo ""
echo "Press Enter to open the editor..."
read

docker exec -it clipsense-worker nano /app/worker.py

echo ""
echo "Save your changes (Ctrl+X, then Y, then Enter)"
echo ""
echo "After saving, restart the worker:"
echo "  docker restart clipsense-worker"
