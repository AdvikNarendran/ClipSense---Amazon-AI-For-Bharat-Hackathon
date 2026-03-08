# Reorganize ClipSense project structure
# Move ALL scripts to scripts/ and docs to docs/

Write-Host "Reorganizing ClipSense project structure..." -ForegroundColor Cyan

# Create directories
New-Item -ItemType Directory -Force -Path "scripts" | Out-Null
New-Item -ItemType Directory -Force -Path "docs" | Out-Null

Write-Host "`nFinding and moving ALL .ps1 and .sh files to scripts/ folder..." -ForegroundColor Yellow

# Find all .ps1 and .sh files recursively (excluding node_modules, .git, etc.)
$allScripts = Get-ChildItem -Path . -Include *.ps1,*.sh -Recurse -File | 
    Where-Object { 
        $_.FullName -notmatch '\\node_modules\\' -and 
        $_.FullName -notmatch '\\.git\\' -and
        $_.FullName -notmatch '\\scripts\\' -and
        $_.Name -ne 'reorganize-project.ps1'
    }

$scriptCount = 0
foreach ($script in $allScripts) {
    $relativePath = $script.FullName.Replace($PWD.Path + "\", "")
    $destination = "scripts\$($script.Name)"
    
    # If file already exists in scripts/, add a prefix based on source folder
    if (Test-Path $destination) {
        $sourceFolder = Split-Path (Split-Path $relativePath -Parent) -Leaf
        if ($sourceFolder) {
            $destination = "scripts\$sourceFolder-$($script.Name)"
        }
    }
    
    Move-Item -Path $script.FullName -Destination $destination -Force
    Write-Host "  Moved: $relativePath -> $destination"
    $scriptCount++
}

Write-Host "`nMoved $scriptCount script files" -ForegroundColor Green

Write-Host "`nMoving documentation to docs/ folder..." -ForegroundColor Yellow

# Documentation files to move (excluding important root-level docs)
$docsToMove = @(
    "AI_FALLBACK_GUIDE.md",
    "ALL_FIXES_COMPLETE.md",
    "AMPLIFY_CONFIG.md",
    "AMPLIFY_FIX_SUMMARY.md",
    "DEPLOYMENT_CHECKLIST.md",
    "DEPLOYMENT_COMPLETE.md",
    "DEPLOYMENT_STATUS_NOW.md",
    "DEPLOYMENT_STATUS_SUMMARY.md",
    "DEPLOY_FIXES_NOW.md",
    "DEPLOY_WORKER_NOW.md",
    "EC2_WORKER_DEPLOYMENT_GUIDE.md",
    "FINAL_DEPLOYMENT_STATUS.md",
    "FINAL_FIX_SUMMARY.md",
    "FIXES_NEEDED.md",
    "FIX_ON_EC2_GUIDE.md",
    "FRONTEND_UPLOAD_FIX.ts",
    "GITHUB_SECRETS_GUIDE.md",
    "PRE_PUSH_VERIFICATION.md",
    "SECURITY_AUDIT_SUMMARY.md",
    "START_WORKER_MANUAL_STEPS.md",
    "SYSTEM_STATUS.md",
    "test-auth.md",
    "UPDATE_GEMINI_KEY_GUIDE.md",
    "UPLOAD_FIX_GUIDE.md",
    "UPLOAD_ISSUE_SUMMARY.md",
    "VERIFY_FIX_GUIDE.md"
)

foreach ($doc in $docsToMove) {
    if (Test-Path $doc) {
        Move-Item -Path $doc -Destination "docs/$doc" -Force
        Write-Host "  Moved: $doc"
    }
}

Write-Host "`nKeeping in root:" -ForegroundColor Green
Write-Host "  README.md"
Write-Host "  ARCHITECTURE.md"
Write-Host "  DEPLOYMENT.md"
Write-Host "  amplify.yml"

Write-Host "`nProject reorganization complete!" -ForegroundColor Green
Write-Host "`nNew structure:"
Write-Host "  scripts/    - All .ps1 and .sh scripts"
Write-Host "  docs/       - Documentation and guides"
Write-Host "  root/       - README, ARCHITECTURE, DEPLOYMENT, amplify.yml"
