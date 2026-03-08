# Enable AWS Transcribe Service
# This script helps you subscribe to AWS Transcribe service

Write-Host "=========================================="
Write-Host "AWS Transcribe Subscription Guide"
Write-Host "=========================================="
Write-Host ""
Write-Host "Your worker is currently using local Whisper for transcription."
Write-Host "To use AWS Transcribe (faster and more accurate), follow these steps:"
Write-Host ""
Write-Host "1. Go to AWS Console: https://console.aws.amazon.com/transcribe/"
Write-Host "2. Click 'Get Started' or 'Subscribe' if prompted"
Write-Host "3. Accept the service terms"
Write-Host "4. Wait a few minutes for activation"
Write-Host ""
Write-Host "Benefits of AWS Transcribe:"
Write-Host "  - Faster transcription (cloud-based)"
Write-Host "  - Better accuracy for various accents"
Write-Host "  - Automatic language detection"
Write-Host "  - Speaker identification"
Write-Host ""
Write-Host "Cost (Free Tier):"
Write-Host "  - First 60 minutes/month: FREE"
Write-Host "  - After that: ~$0.024/minute"
Write-Host ""
Write-Host "Current Status: Using local Whisper (works fine, just slower)"
Write-Host ""
Write-Host "=========================================="
Write-Host "Testing AWS Transcribe Access"
Write-Host "=========================================="
Write-Host ""

# Test if Transcribe is accessible
Write-Host "Checking if AWS Transcribe is available..."
aws transcribe list-transcription-jobs --max-results 1 --region ap-south-1 2>&1 | Out-Null

if ($LASTEXITCODE -eq 0) {
    Write-Host "✅ AWS Transcribe is accessible!"
    Write-Host "Your worker will automatically use it for transcription."
} else {
    Write-Host "⚠️  AWS Transcribe requires subscription"
    Write-Host "Follow the steps above to enable it."
    Write-Host ""
    Write-Host "Note: Your system works fine with local Whisper!"
    Write-Host "AWS Transcribe is optional for better performance."
}

Write-Host ""
