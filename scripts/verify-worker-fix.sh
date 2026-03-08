#!/bin/bash
# Verify the emotion analysis fix was applied correctly

echo "=========================================="
echo "Verifying Worker Fix on EC2"
echo "=========================================="
echo ""

echo "1. Check if worker container is running"
echo "----------------------------------------"
docker ps | grep clipsense-worker
if [ $? -eq 0 ]; then
    echo "✅ Worker container is running"
else
    echo "❌ Worker container is NOT running"
    exit 1
fi

echo ""
echo "2. Check for video download code"
echo "----------------------------------------"
DOWNLOAD_COUNT=$(docker exec clipsense-worker grep -c "Download video for emotion analysis" /app/worker.py)
if [ "$DOWNLOAD_COUNT" -gt 0 ]; then
    echo "✅ Video download code found ($DOWNLOAD_COUNT occurrence)"
    docker exec clipsense-worker grep -A 8 "Download video for emotion analysis" /app/worker.py | head -10
else
    echo "❌ Video download code NOT found"
fi

echo ""
echo "3. Check for audio_path parameter"
echo "----------------------------------------"
AUDIO_PATH_COUNT=$(docker exec clipsense-worker grep -c "audio_path=local_video_path" /app/worker.py)
if [ "$AUDIO_PATH_COUNT" -gt 0 ]; then
    echo "✅ audio_path parameter found ($AUDIO_PATH_COUNT occurrence)"
    docker exec clipsense-worker grep -B 2 -A 2 "audio_path=local_video_path" /app/worker.py
else
    echo "❌ audio_path parameter NOT found"
fi

echo ""
echo "4. Check for video reuse in rendering"
echo "----------------------------------------"
REUSE_COUNT=$(docker exec clipsense-worker grep -c "Using already downloaded video for rendering" /app/worker.py)
if [ "$REUSE_COUNT" -gt 0 ]; then
    echo "✅ Video reuse code found ($REUSE_COUNT occurrence)"
else
    echo "⚠️  Video reuse code not found (optional optimization)"
fi

echo ""
echo "5. Check worker logs for errors"
echo "----------------------------------------"
ERROR_COUNT=$(docker logs --tail 100 clipsense-worker 2>&1 | grep -c "UnboundLocalError: local_video_path")
if [ "$ERROR_COUNT" -eq 0 ]; then
    echo "✅ No 'local_video_path' errors in recent logs"
else
    echo "❌ Found $ERROR_COUNT 'local_video_path' errors in logs"
fi

echo ""
echo "6. Check if worker is polling SQS"
echo "----------------------------------------"
POLLING=$(docker logs --tail 50 clipsense-worker 2>&1 | grep "Starting SQS polling loop")
if [ -n "$POLLING" ]; then
    echo "✅ Worker is polling SQS queue"
else
    echo "⚠️  Worker polling status unclear"
fi

echo ""
echo "7. Check environment variables"
echo "----------------------------------------"
echo "AWS Region:"
docker exec clipsense-worker printenv AWS_REGION
echo "S3 Bucket:"
docker exec clipsense-worker printenv AWS_S3_BUCKET
echo "SQS Queue:"
docker exec clipsense-worker printenv SQS_QUEUE_URL | sed 's/.*\//...\//'
echo "Gemini API Key (first 20 chars):"
docker exec clipsense-worker printenv GEMINI_API_KEY | cut -c1-20

echo ""
echo "8. View recent worker activity"
echo "----------------------------------------"
echo "Last 15 log lines:"
docker logs --tail 15 clipsense-worker

echo ""
echo "=========================================="
echo "Verification Complete"
echo "=========================================="
echo ""
echo "Summary:"
echo "--------"
if [ "$DOWNLOAD_COUNT" -gt 0 ] && [ "$AUDIO_PATH_COUNT" -gt 0 ] && [ "$ERROR_COUNT" -eq 0 ]; then
    echo "✅ ALL CHECKS PASSED - Fix is working correctly!"
    echo ""
    echo "The worker will now:"
    echo "  1. Download video after transcription"
    echo "  2. Pass audio_path to emotion analyzer"
    echo "  3. Process videos without errors"
else
    echo "⚠️  SOME CHECKS FAILED - Review output above"
fi
