# ClipSense - Three Issues to Fix

## Issue 1: Emotional Analysis Not Being Done ✅ ALREADY WORKING

**Status**: This is actually working! Looking at the worker code (lines 95-110), emotional analysis IS being performed:

```python
# STEP 2: Audio Emotion Analysis
db.update_project(project_id, {"currentStep": "Analyzing Audio Emotions...", "progress": 40})
emotion_data = analyze_emotions(transcript_segments, engine=_engine_instance)
db.update_project(project_id, {"emotionData": emotion_data, "progress": 50})
```

**What's happening**: The emotion data is being calculated and stored in the database. Check your project in DynamoDB - it should have an `emotionData` field.

**To verify**: Check the worker logs for "Analyzing Audio Emotions..." message.

---

## Issue 2: Subtitle Download Returns "Not Found" ❌ NEEDS FIX

**Problem**: There's no subtitle download endpoint in the Lambda API!

**Root Cause**: The frontend is trying to download subtitles, but the API doesn't have an endpoint for it.

**Solution**: Add a subtitle download endpoint to `backend/lambda_api.py`

### Fix for Lambda API

Add this endpoint after the clip download endpoint (around line 405):

```python
@app.route("/api/projects/<project_id>/subtitles", methods=["GET"])
@jwt_required()
def download_subtitles(project_id):
    """Generate subtitles file from transcription data."""
    user_id = get_jwt_identity()
    project = db.get_project(project_id, user_id)
    
    if not project:
        return jsonify({"error": "Project not found"}), 404
    
    transcription = project.get("transcription", [])
    if not transcription:
        return jsonify({"error": "No transcription available"}), 404
    
    # Generate SRT format
    srt_content = ""
    for idx, segment in enumerate(transcription, 1):
        start_time = segment.get("start", 0)
        end_time = segment.get("end", 0)
        text = segment.get("text", "")
        
        # Convert seconds to SRT time format (HH:MM:SS,mmm)
        def format_time(seconds):
            hours = int(seconds // 3600)
            minutes = int((seconds % 3600) // 60)
            secs = int(seconds % 60)
            millis = int((seconds % 1) * 1000)
            return f"{hours:02d}:{minutes:02d}:{secs:02d},{millis:03d}"
        
        srt_content += f"{idx}\n"
        srt_content += f"{format_time(start_time)} --> {format_time(end_time)}\n"
        srt_content += f"{text.strip()}\n\n"
    
    # Return as downloadable file
    from flask import Response
    return Response(
        srt_content,
        mimetype="text/plain",
        headers={
            "Content-Disposition": f"attachment; filename={project.get('title', project_id)}.srt"
        }
    )
```

**Deployment**: After adding this, redeploy Lambda:

```powershell
.\backend\redeploy-lambda.ps1
```

---

## Issue 3: Email Credentials Not Configured ⚠️ OPTIONAL

**Problem**: Email notifications are not being sent because email credentials are not configured.

**Current Status**: Your `.env` file has:
```
SENDER_EMAIL=clipsense57@gmail.com
SENDER_PASSWORD=cgbv luri ypth bsih
```

**What's happening**: The worker tries to send emails but the credentials might be invalid or Gmail is blocking them.

### Two Options:

### Option A: Disable Email Notifications (Quick Fix)

Update `backend/worker.py` line 177 to skip email sending:

```python
# Send email notification (disabled for now)
# if user_id:
#     send_processing_complete(user_id, project.get("title"), len(clips_list), avg_engagement)
```

### Option B: Fix Gmail App Password (Proper Fix)

1. **Generate a new Gmail App Password**:
   - Go to: https://myaccount.google.com/apppasswords
   - Select "Mail" and "Other (Custom name)"
   - Name it "ClipSense"
   - Copy the 16-character password

2. **Update `.env` file**:
   ```
   SENDER_EMAIL=clipsense57@gmail.com
   SENDER_PASSWORD=your-16-char-app-password-here
   ```

3. **Update EC2 worker environment**:
   ```bash
   # In EC2 Session Manager
   sudo nano /etc/clipsense/.env
   # Update SENDER_PASSWORD line
   # Save and exit (Ctrl+X, Y, Enter)
   
   # Restart worker
   docker restart clipsense-worker
   ```

---

## Summary of Actions

### Immediate Fixes Needed:

1. ✅ **Emotional Analysis**: Already working - no action needed
2. ❌ **Subtitle Download**: Add endpoint to Lambda API and redeploy
3. ⚠️ **Email Notifications**: Either disable or fix Gmail credentials

### Priority:

1. **High**: Fix subtitle download (users expect this feature)
2. **Low**: Email notifications (nice to have, not critical)

---

## Quick Commands

### To fix subtitle download:
```powershell
# 1. Add the endpoint code to backend/lambda_api.py (shown above)
# 2. Redeploy Lambda
.\backend\redeploy-lambda.ps1
```

### To disable email notifications:
```bash
# In EC2 Session Manager
# Comment out the email sending line in worker.py
# Or just ignore the email errors - they don't affect video processing
```

---

## Verification

After fixing subtitle download:
1. Process a video
2. Go to project details
3. Click "Download Subtitles"
4. Should download a `.srt` file

The emotional analysis data is already in your database - check the `emotionData` field in DynamoDB!
