# AWS Amplify Configuration for ClipSense Frontend

## Simple Step-by-Step Guide

### Step 1: Connect Your GitHub Repository

1. Go to [AWS Amplify Console](https://console.aws.amazon.com/amplify)
2. Click **"New app"** → **"Host web app"**
3. Choose **GitHub** as your source
4. Click **"Connect to GitHub"** and authorize AWS Amplify
5. Select your repository: `yourusername/clipsense`
6. Select branch: `main`
7. Click **"Next"**

### Step 2: Configure Build Settings

Amplify will auto-detect the `amplify.yml` file. Just verify:

- **App name**: ClipSense (or whatever you prefer)
- **Build command**: `npm run build`
- **Output directory**: `frontend/.next`

Click **"Next"**

### Step 3: Add Environment Variables

This is the MOST IMPORTANT step! Click **"Advanced settings"** and add these:

| Key | Value | Where to get it |
|-----|-------|-----------------|
| `NEXT_PUBLIC_API_URL` | `https://xxx.execute-api.ap-south-1.amazonaws.com` | From `setup-api-gateway.ps1` output |
| `NEXT_PUBLIC_AWS_REGION` | `ap-south-1` | Your AWS region |
| `NEXT_PUBLIC_S3_BUCKET` | `clipsense-media-storage-cs` | From your .env file |

**Example**:
```
NEXT_PUBLIC_API_URL=https://abc123xyz.execute-api.ap-south-1.amazonaws.com
NEXT_PUBLIC_AWS_REGION=ap-south-1
NEXT_PUBLIC_S3_BUCKET=clipsense-media-storage-cs
```

### Step 4: Deploy

1. Click **"Save and deploy"**
2. Wait 5-10 minutes for the first build
3. You'll get a URL like: `https://main.d1234abcd.amplifyapp.com`

### Step 5: Test Your App

1. Open the Amplify URL
2. Try to register a new account
3. Try to login
4. Try to upload a video

## Troubleshooting

### Frontend loads but API calls fail
- Check `NEXT_PUBLIC_API_URL` is correct
- Verify API Gateway CORS is configured
- Check Lambda function is running

### Build fails
- Check Amplify build logs
- Verify `amplify.yml` is in root directory
- Check `package.json` has correct scripts

### Can't upload videos
- Verify S3 bucket CORS is configured
- Check Lambda has S3 permissions
- Verify SQS queue exists

## After Amplify is Configured

Your app is ALMOST ready! Here's what happens:

1. ✅ Frontend is live on Amplify URL
2. ✅ Users can register/login via Lambda API
3. ✅ Users can upload videos (saved to S3)
4. ✅ Lambda sends job to SQS queue
5. ✅ EC2 worker processes videos
6. ✅ Clips are generated and saved to S3
7. ✅ Users can download clips

## Is Everything Working?

Test the complete flow:
1. Open Amplify URL
2. Register account → Should work
3. Login → Should work
4. Upload video → Should work
5. Wait for processing → Check EC2 worker logs
6. Download clips → Should work

If all steps work, **YOUR APP IS FULLY DEPLOYED! 🎉**

