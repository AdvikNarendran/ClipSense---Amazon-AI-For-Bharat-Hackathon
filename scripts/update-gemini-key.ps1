# Update Gemini API Key
# This script updates the Gemini API key in both local .env and EC2 worker

param(
    [Parameter(Mandatory=$true)]
    [string]$NewGeminiKey
)

Write-Host "=========================================="
Write-Host "Updating Gemini API Key"
Write-Host "=========================================="
Write-Host ""

# Step 1: Update local .env file
Write-Host "Step 1: Updating backend/.env file..."
$envPath = "backend/.env"

if (Test-Path $envPath) {
    $envContent = Get-Content $envPath
    $updated = $false
    
    $newContent = $envContent | ForEach-Object {
        if ($_ -match '^GEMINI_API_KEY=') {
            "GEMINI_API_KEY=$NewGeminiKey"
            $updated = $true
        } else {
            $_
        }
    }
    
    if ($updated) {
        $newContent | Set-Content $envPath
        Write-Host "✅ Updated backend/.env"
    } else {
        Add-Content $envPath "`nGEMINI_API_KEY=$NewGeminiKey"
        Write-Host "✅ Added GEMINI_API_KEY to backend/.env"
    }
} else {
    Write-Host "❌ backend/.env not found"
    exit 1
}

Write-Host ""

# Step 2: Update EC2 worker environment
Write-Host "Step 2: Updating EC2 worker environment..."
Write-Host ""
Write-Host "Connecting to EC2 instance via Session Manager..."
Write-Host ""

# Create temporary script for EC2
$ec2Script = @"
#!/bin/bash
set -e

echo "Updating /etc/clipsense/.env on EC2..."

# Update the .env file
sudo sed -i 's/^GEMINI_API_KEY=.*/GEMINI_API_KEY=$NewGeminiKey/' /etc/clipsense/.env

echo "Restarting worker container..."
docker restart clipsense-worker

echo ""
echo "✅ Gemini API key updated on EC2!"
echo ""
echo "Checking worker status..."
sleep 3
docker logs clipsense-worker --tail 10
"@

$ec2Script | Out-File -FilePath "temp-update-gemini.sh" -Encoding ASCII -NoNewline

Write-Host "To update the EC2 worker, run these commands:"
Write-Host ""
Write-Host "Option 1: Via AWS Session Manager (Recommended)"
Write-Host "----------------------------------------------"
Write-Host "1. Go to AWS Console > EC2 > Instances"
Write-Host "2. Select instance: i-039398804f9156503"
Write-Host "3. Click 'Connect' > 'Session Manager' > 'Connect'"
Write-Host "4. Run these commands:"
Write-Host ""
Write-Host "sudo sed -i 's/^GEMINI_API_KEY=.*/GEMINI_API_KEY=$NewGeminiKey/' /etc/clipsense/.env"
Write-Host "docker restart clipsense-worker"
Write-Host "docker logs clipsense-worker --tail 10"
Write-Host ""
Write-Host "Option 2: Via SSH (if configured)"
Write-Host "----------------------------------------------"
Write-Host "ssh -i ~/.ssh/clipsense-worker-key.pem ec2-user@65.2.151.98"
Write-Host "sudo sed -i 's/^GEMINI_API_KEY=.*/GEMINI_API_KEY=$NewGeminiKey/' /etc/clipsense/.env"
Write-Host "docker restart clipsense-worker"
Write-Host ""
Write-Host "=========================================="
Write-Host "Summary"
Write-Host "=========================================="
Write-Host ""
Write-Host "✅ Local .env file updated"
Write-Host "⚠️  EC2 worker needs manual update (see commands above)"
Write-Host ""
Write-Host "After updating EC2, your new Gemini key will be active!"
Write-Host ""

# Cleanup
Remove-Item "temp-update-gemini.sh" -ErrorAction SilentlyContinue
