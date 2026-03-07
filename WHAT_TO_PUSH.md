# What to Push to GitHub

## ✅ PUSH These Folders/Files

```
ClipSense/
├── .github/                    # GitHub Actions workflows
│   └── workflows/
│       ├── deploy-lambda.yml
│       ├── deploy-worker.yml
│       └── deploy-frontend.yml
├── backend/                    # All backend code
│   ├── *.py                   # All Python files
│   ├── *.sh                   # Bash setup scripts
│   ├── *.ps1                  # PowerShell setup scripts
│   ├── Dockerfile.lambda      # Lambda Docker config
│   ├── Dockerfile.worker      # Worker Docker config
│   ├── requirements.txt       # Full dependencies
│   ├── requirements-lambda.txt # Lambda dependencies
│   └── scripts/               # Test scripts
├── frontend/                   # All frontend code
│   ├── src/
│   ├── public/
│   ├── package.json
│   ├── next.config.js
│   └── tsconfig.json
├── .kiro/                     # Spec files (optional)
├── amplify.yml                # Amplify build config
├── .gitignore                 # Updated gitignore
├── DEPLOYMENT.md              # Deployment guide
├── ARCHITECTURE.md            # Architecture docs
├── AMPLIFY_CONFIG.md          # Amplify setup guide
├── GITHUB_SECRETS_GUIDE.md    # This guide
└── README.md                  # Project readme
```

## ❌ DO NOT PUSH These

```
❌ backend/.env                 # Contains secrets!
❌ backend/uploads/             # User uploaded videos
❌ backend/generated_clips/     # Generated clips
❌ backend/__pycache__/         # Python cache
❌ backend/venv/                # Virtual environment
❌ frontend/.env.local          # Local environment
❌ frontend/.next/              # Build output
❌ frontend/node_modules/       # Dependencies
❌ *.pem                        # SSH keys
❌ *.log                        # Log files
```

## How to Push

```bash
# 1. Check what will be pushed
git status

# 2. Add all files (gitignore will exclude sensitive files)
git add .

# 3. Commit
git commit -m "Add cloud deployment configuration"

# 4. Push to GitHub
git push origin main
```

## Verify Before Pushing

Run this to make sure no secrets are included:
```bash
git status | grep -E "\.env|\.pem|\.ppk"
```

If you see any .env or .pem files, they should NOT be pushed!
