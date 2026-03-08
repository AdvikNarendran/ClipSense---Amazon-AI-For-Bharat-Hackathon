# GitHub Secrets Configuration Guide

## What are GitHub Secrets?
GitHub Secrets are encrypted environment variables that GitHub Actions workflows use to deploy your app automatically. Think of them as passwords that GitHub stores safely.

## How to Add Secrets

1. Go to your GitHub repository
2. Click **Settings** (top menu)
3. Click **Secrets and variables** → **Actions** (left sidebar)
4. Click **New repository secret** button
5. Add each secret below one by one

## Required Secrets

### 1. AWS_ACCESS_KEY_ID
**What it is**: Your AWS account access key (like a username)

**Where to get it**: 
- Check your `.env` file for `AWS_ACCESS_KEY_ID`
- Or create new one: AWS Console → IAM → Users → Your User → Security Credentials → Create Access Key

**Value to paste**:
```
<your-aws-access-key-id>
```

---

### 2. AWS_SECRET_ACCESS_KEY
**What it is**: Your AWS secret key (like a password)

**Where to get it**: 
- Check your `.env` file for `AWS_SECRET_ACCESS_KEY`
- Or from the same place you got the access key

**Value to paste**:
```
<your-aws-secret-access-key>
```

---

### 3. EC2_WORKER_HOST
**What it is**: The public IP address of your EC2 worker instance

**Where to get it**: 
- After running `setup-ec2.ps1`, it will show you the public IP
- Or: AWS Console → EC2 → Instances → Select your instance → Copy "Public IPv4 address"

**Value to paste** (example):
```
13.234.56.78
```

---

### 4. EC2_SSH_KEY
**What it is**: The private key file content for SSH access to EC2

**Where to get it**: 
- Open the file: `C:\Users\dell\.ssh\clipsense-worker-key.pem`
- Copy the ENTIRE content (including `-----BEGIN RSA PRIVATE KEY-----` and `-----END RSA PRIVATE KEY-----`)

**Value to paste** (entire file content):
```
-----BEGIN RSA PRIVATE KEY-----
MIIEpAIBAAKCAQEA...
(all the lines)
...
-----END RSA PRIVATE KEY-----
```

---

### 5. API_GATEWAY_URL
**What it is**: The URL of your API Gateway endpoint

**Where to get it**: 
- After running `setup-api-gateway.ps1`, it will show you the API endpoint
- Or: AWS Console → API Gateway → Your API → Copy "Invoke URL"

**Value to paste** (example):
```
https://abc123xyz.execute-api.ap-south-1.amazonaws.com
```

---

## Summary

You need to add exactly 5 secrets:
1. ✅ AWS_ACCESS_KEY_ID
2. ✅ AWS_SECRET_ACCESS_KEY
3. ✅ EC2_WORKER_HOST (get after EC2 setup)
4. ✅ EC2_SSH_KEY (from your .pem file)
5. ✅ API_GATEWAY_URL (get after API Gateway setup)

Once these are added, GitHub Actions will automatically deploy your code when you push to the main branch!
