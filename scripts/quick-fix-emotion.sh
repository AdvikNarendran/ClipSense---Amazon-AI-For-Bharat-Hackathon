#!/bin/bash
# Quick fix for emotion analysis - run in EC2 Session Manager

echo "Fixing emotion analysis in worker container..."

# Create Python script to patch the file
docker exec clipsense-worker python3 << 'PYTHON_EOF'
import re

# Read the current worker.py
with open('/app/worker.py', 'r') as f:
    content = f.read()

# Backup
with open('/app/worker.py.backup', 'w') as f:
    f.write(content)

# Fix 1: Add audio_path parameter to analyze_emotions call
content = content.replace(
    'emotion_data = analyze_emotions(transcript_segments, engine=_engine_instance)',
    'emotion_data = analyze_emotions(transcript_segments, audio_path=local_video_path, engine=_engine_instance)'
)

# Fix 2: Move video download before emotion analysis
# Find the emotion analysis section
emotion_section_start = content.find('# STEP 2: Audio Emotion Analysis')
rendering_section = content.find('# STEP 4: Rendering')

# Find the video download code in STEP 4
download_start = content.find('# Download video from S3', rendering_section)
download_end = content.find('s3.download_file(bucket, key, local_video_path)', download_start) + len('s3.download_file(bucket, key, local_video_path)')

if download_start > 0 and download_end > download_start:
    # Extract download code
    download_code = content[download_start:download_end]
    
    # Remove from STEP 4
    content = content[:download_start] + '# Video already downloaded for emotion analysis, reuse it\n        logger.info("[WORKER] Using already downloaded video for rendering")' + content[download_end:]
    
    # Insert before emotion analysis
    insert_point = emotion_section_start
    content = content[:insert_point] + '# STEP 2: Download video for emotion analysis\n        ' + download_code.strip() + '\n\n        ' + content[insert_point:]

# Write the patched file
with open('/app/worker.py', 'w') as f:
    f.write(content)

print("✅ worker.py patched successfully!")
PYTHON_EOF

if [ $? -eq 0 ]; then
    echo "✅ Patch applied!"
    echo "Restarting worker..."
    docker restart clipsense-worker
    sleep 3
    echo ""
    echo "Worker logs:"
    docker logs clipsense-worker --tail 20
    echo ""
    echo "✅ Done! Emotion analysis should now work."
else
    echo "❌ Patch failed"
    exit 1
fi
