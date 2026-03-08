# Update Gemini API Key Guide

## Quick Update Process

You need to update the Gemini API key in two places:
1. Local `backend/.env` file
2. EC2 worker environment file

---

## Method 1: Automated Script (Recommended)

Run this PowerShell script with your new API key:

```powershell
.\update-gemini-key.ps1 -NewGeminiKey "YOUR_NEW_GEMINI_API_KEY"
```

This will:
- ✅ Update your local `backend/.env` file
- ⚠️ Show you commands to update EC2 (manual step required)

---

## Method 2: Manual Update

### Step 1: Update Local .env File

1. Open `backend/.env` in a text editor
2. Find the line: `GEMINI_API_KEY=AIzaSy...`
3. Replace with your new key: `GEMINI_API_KEY=YOUR_NEW_KEY`
4. Save the file

### Step 2: Update EC2 Worker

#### Option A: Via AWS Session Manager (Easiest)

1. Go to **AWS Console** > **EC2** > **Instances**
2. Select instance: `i-039398804f9156503`
3. Click **"Connect"** > **"Session Manager"** > **"Connect"**
4. Run these commands:

```bash
# Switch to ec2-user
sudo su - ec2-user

# Update the environment file
sudo sed -i 's/^GEMINI_API_KEY=.*/GEMINI_API_KEY=YOUR_NEW_KEY/' /etc/clipsense/.env

# Restart the worker to pick up new key
docker restart clipsense-worker

# Verify it's running
docker logs clipsense-worker --tail 20
```

#### Option B: Via SSH (If Configured)

```bash
ssh -i ~/.ssh/clipsense-worker-key.pem ec2-user@65.2.151.98

# Update the environment file
sudo sed -i 's/^GEMINI_API_KEY=.*/GEMINI_API_KEY=YOUR_NEW_KEY/' /etc/clipsense/.env

# Restart the worker
docker restart clipsense-worker

# Verify it's running
docker logs clipsense-worker --tail 20
```

---

## Verification

After updating, verify the worker is using the new key:

```bash
# Check worker logs for any API errors
docker logs clipsense-worker -f

# You should see successful AI analysis logs
# Look for: "AI Selection (Gemini)..." or "Bedrock generation failed... Falling back to Gemini"
```

---

## Get a New Gemini API Key

If you need a new Gemini API key:

1. Go to: https://aistudio.google.com/app/apikey
2. Click **"Create API Key"**
3. Select your Google Cloud project (or create one)
4. Copy the generated API key
5. Use it in the update process above

**Note**: Gemini API is free with generous limits (15 requests/minute).

---

## Troubleshooting

### Worker not restarting
```bash
# Stop and start manually
docker stop clipsense-worker
docker start clipsense-worker
```

### Key not updating
```bash
# Verify the .env file was updated
sudo cat /etc/clipsense/.env | grep GEMINI_API_KEY

# If incorrect, edit manually
sudo nano /etc/clipsense/.env
# Update the GEMINI_API_KEY line
# Press Ctrl+X, then Y, then Enter to save

# Restart worker
docker restart clipsense-worker
```

### Worker crashes after update
```bash
# Check logs for errors
docker logs clipsense-worker --tail 50

# Common issues:
# - Invalid API key format
# - Missing quotes in .env file
# - Typo in key
```

---

## Important Notes

1. **No quotes needed** in .env file:
   - ✅ Correct: `GEMINI_API_KEY=AIzaSy...`
   - ❌ Wrong: `GEMINI_API_KEY="AIzaSy..."`

2. **Restart required**: Worker must be restarted to pick up new key

3. **No downtime**: Restarting worker takes ~5 seconds

4. **Active jobs**: Any video currently processing will continue with old key, new videos will use new key

---

## Quick Reference

### Update local .env:
```powershell
# Edit backend/.env and change GEMINI_API_KEY line
```

### Update EC2 worker:
```bash
sudo sed -i 's/^GEMINI_API_KEY=.*/GEMINI_API_KEY=YOUR_NEW_KEY/' /etc/clipsense/.env
docker restart clipsense-worker
```

### Verify:
```bash
docker logs clipsense-worker --tail 20
```

---

## Need Help?

If you encounter issues:
1. Check worker logs: `docker logs clipsense-worker -f`
2. Verify .env file: `sudo cat /etc/clipsense/.env | grep GEMINI`
3. Check worker status: `docker ps | grep clipsense-worker`
4. Restart if needed: `docker restart clipsense-worker`
