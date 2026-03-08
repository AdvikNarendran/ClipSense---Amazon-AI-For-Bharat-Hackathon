# Deploy Fixes - Action Plan

## Current Status

✅ **Subtitle Download Fix**: Code is ready in `backend/lambda_api.py` (lines 405-440)
✅ **Emotion Analysis Fix**: Code is ready in `backend/worker.py` (line 104)
❌ **Worker Container**: NOT RUNNING on EC2

## Priority 1: Start Worker Container (URGENT)

The worker container must be running for video processing to work.

### Steps:
1. Connect to EC2 instance `i-039398804f9156503` via EC2 Instance Connect
2. Run this command:
   ```bash
   docker ps | grep clipsense-worker || docker start clipsense-worker || docker run -d --name clipsense-worker --env-file /etc/clipsense/.env --restart unless-stopped $(docker images --format "{{.Repository}}:{{.Tag}}" | grep clipsense-worker | head -1)
   ```
3. Verify: `docker logs --tail 30 clipsense-worker`

**See `START_WORKER_MANUAL_STEPS.md` for detailed instructions.**

## Priority 2: Deploy Lambda (Subtitle Fix)

Once worker is running, deploy the Lambda with subtitle download endpoint.

### Steps:
```powershell
# From your local machine (Windows PowerShell)
cd backend
.\redeploy-lambda.ps1
```

This will:
- Package the updated Lambda code
- Upload to AWS Lambda
- The subtitle endpoint will be immediately available

## Priority 3: Test Everything

After both deployments:

1. **Upload a test video** (small file, 1-2 minutes)
2. **Wait for processing** to complete
3. **Check emotion analysis**:
   - Go to project details
   - Look for emotion data in the UI
   - Should show intensity scores and emotions
4. **Test subtitle download**:
   - Click "Download Subtitles" button
   - Should download a `.srt` file

## What About Emotion Analysis?

The emotion fix is in your local code but NOT in the running container. You have two options:

### Option A: Test First (Recommended)
1. Start the container with existing code
2. Process a video and see if emotion analysis works
3. If it doesn't work, proceed to Option B

### Option B: Deploy Updated Worker
If emotion analysis doesn't work after testing, we need to rebuild the worker:

```powershell
# This will take 10-15 minutes
cd backend

# Build new Docker image
docker build -f Dockerfile.worker -t clipsense-worker:latest .

# Tag for ECR
docker tag clipsense-worker:latest 732772501496.dkr.ecr.ap-south-1.amazonaws.com/clipsense-worker:latest

# Login to ECR
aws ecr get-login-password --region ap-south-1 | docker login --username AWS --password-stdin 732772501496.dkr.ecr.ap-south-1.amazonaws.com

# Push to ECR
docker push 732772501496.dkr.ecr.ap-south-1.amazonaws.com/clipsense-worker:latest

# Then on EC2, pull and restart:
# (via EC2 Instance Connect)
docker pull 732772501496.dkr.ecr.ap-south-1.amazonaws.com/clipsense-worker:latest
docker stop clipsense-worker
docker rm clipsense-worker
docker run -d --name clipsense-worker --env-file /etc/clipsense/.env --restart unless-stopped 732772501496.dkr.ecr.ap-south-1.amazonaws.com/clipsense-worker:latest
```

## Timeline

- **Now**: Start worker container (5 minutes)
- **+5 min**: Deploy Lambda (5 minutes)
- **+10 min**: Test with video upload (depends on video length)
- **If needed**: Deploy updated worker (15 minutes)

## Commands Ready to Copy-Paste

### On EC2 (via Instance Connect):
```bash
# Start worker
docker ps | grep clipsense-worker || docker start clipsense-worker || docker run -d --name clipsense-worker --env-file /etc/clipsense/.env --restart unless-stopped $(docker images --format "{{.Repository}}:{{.Tag}}" | grep clipsense-worker | head -1)

# Check logs
docker logs --tail 30 clipsense-worker

# Verify Gemini key
docker exec clipsense-worker printenv GEMINI_API_KEY
```

### On Local Machine (PowerShell):
```powershell
# Deploy Lambda
cd backend
.\redeploy-lambda.ps1
```

## Success Criteria

✅ Worker container running and polling SQS
✅ Lambda deployed with subtitle endpoint
✅ Video processing completes successfully
✅ Emotion analysis data appears in UI
✅ Subtitle download works

## Need Help?

If you encounter any issues:
1. Share the error message
2. Share relevant logs: `docker logs clipsense-worker --tail 50`
3. I'll help troubleshoot
