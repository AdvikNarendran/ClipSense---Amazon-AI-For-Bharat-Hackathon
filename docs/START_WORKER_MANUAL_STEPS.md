# Manual Steps to Start Worker and Apply Fixes

## Problem
The EC2 worker container is not running. We need to:
1. Start the worker container
2. Verify it's working
3. Deploy Lambda with subtitle fix

## Option 1: Using EC2 Instance Connect (Easiest)

1. Go to AWS Console → EC2 → Instances
2. Select instance `i-039398804f9156503`
3. Click "Connect" → "EC2 Instance Connect" → "Connect"
4. Run these commands in the terminal:

```bash
# Step 1: Check current status
echo "=== Checking Docker Status ==="
docker ps -a
docker images | grep clipsense

# Step 2: Start the worker container
echo "=== Starting Worker Container ==="

# If container exists but is stopped:
docker start clipsense-worker

# If container doesn't exist, create it:
docker run -d \
  --name clipsense-worker \
  --env-file /etc/clipsense/.env \
  --restart unless-stopped \
  $(docker images --format "{{.Repository}}:{{.Tag}}" | grep clipsense-worker | head -1)

# Step 3: Verify it's running
echo "=== Verifying Worker ==="
docker ps | grep clipsense-worker
docker logs --tail 30 clipsense-worker

# Step 4: Check Gemini API key is set
docker exec clipsense-worker printenv GEMINI_API_KEY
```

## Option 2: Using SSH (If you have the key)

```powershell
# From your local machine
ssh -i "C:\Users\dell\.ssh\clipsense-worker-key.pem" ec2-user@65.2.151.98

# Then run the same commands as Option 1
```

## Expected Output

After starting the container, you should see:
```
ClipSense EC2 Worker Starting
============================================================
AWS Region: ap-south-1
S3 Bucket: clipsense-media-storage-cs
DynamoDB Table: ClipSense-Projects
SQS Queue: https://sqs.ap-south-1.amazonaws.com/732772501496/clipsense-processing-queue
============================================================
[WORKER] Starting SQS polling loop...
```

## Verification Checklist

- [ ] Container is running: `docker ps | grep clipsense-worker`
- [ ] Gemini API key is set: Should show `AIzaSyDw2QxVe34KE3OwZ-ldl7VTzsd1YqY0rFg`
- [ ] Worker is polling SQS: Check logs for "Starting SQS polling loop"
- [ ] No errors in logs: `docker logs clipsense-worker --tail 50`

## What About the Emotion Analysis Fix?

**Good news**: The emotion analysis fix is ALREADY in your local `backend/worker.py` file (line 104):
```python
emotion_data = analyze_emotions(transcript_segments, audio_path=local_video_path, engine=_engine_instance)
```

However, the running container has the OLD code. You have two options:

### Option A: Quick Test (Just Start Container)
Start the container as-is and test if emotion analysis works. The old code might still work partially.

### Option B: Deploy Updated Code (Recommended)
After starting the container, we need to rebuild and deploy the updated worker image with the emotion fix.

## Next Steps After Worker is Running

1. **Deploy Lambda with subtitle fix**:
   ```powershell
   # From your local machine
   .\backend\redeploy-lambda.ps1
   ```

2. **Test the system**:
   - Upload a video
   - Check if processing completes
   - Verify emotion analysis appears
   - Test subtitle download

3. **If emotion analysis still doesn't work**, we'll need to deploy the updated worker code.

## Troubleshooting

### If container won't start:
```bash
# Check for errors
docker logs clipsense-worker

# Remove old container and recreate
docker rm -f clipsense-worker
docker run -d --name clipsense-worker --env-file /etc/clipsense/.env --restart unless-stopped $(docker images --format "{{.Repository}}:{{.Tag}}" | grep clipsense-worker | head -1)
```

### If no Docker image exists:
You'll need to rebuild and push the image. Let me know and I'll provide those steps.

### If environment file is missing:
```bash
# Check if it exists
ls -la /etc/clipsense/.env

# If missing, recreate it (I'll provide the content)
```

## Quick Command Summary

```bash
# One-liner to start everything:
docker ps | grep clipsense-worker || docker start clipsense-worker || docker run -d --name clipsense-worker --env-file /etc/clipsense/.env --restart unless-stopped $(docker images --format "{{.Repository}}:{{.Tag}}" | grep clipsense-worker | head -1)

# Check status:
docker ps && docker logs --tail 20 clipsense-worker
```
