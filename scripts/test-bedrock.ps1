# Test AWS Bedrock Claude 3 Haiku Access

Write-Host "Testing AWS Bedrock Access..."
Write-Host ""

# Create the JSON payload
$jsonPayload = @{
    anthropic_version = "bedrock-2023-05-31"
    max_tokens = 100
    messages = @(
        @{
            role = "user"
            content = "Say hello in one sentence"
        }
    )
} | ConvertTo-Json -Depth 10 -Compress

# Save to temp file
$tempFile = [System.IO.Path]::GetTempFileName()
$jsonPayload | Out-File -FilePath $tempFile -Encoding utf8 -NoNewline

Write-Host "Invoking Claude 3 Haiku model..."
Write-Host ""

# Invoke the model
aws bedrock-runtime invoke-model `
    --model-id "anthropic.claude-3-haiku-20240307-v1:0" `
    --body "file://$tempFile" `
    --region ap-south-1 `
    output.json

if ($LASTEXITCODE -eq 0) {
    Write-Host "✅ SUCCESS! Bedrock is working!"
    Write-Host ""
    Write-Host "Response:"
    Get-Content output.json | ConvertFrom-Json | ConvertTo-Json -Depth 10
    Write-Host ""
    Write-Host "=========================================="
    Write-Host "✅ Bedrock is Ready!"
    Write-Host "=========================================="
    Write-Host ""
    Write-Host "Your EC2 worker will automatically use Bedrock now."
    Write-Host "No changes needed - just upload a video and it will use Claude 3 Haiku!"
} else {
    Write-Host "❌ FAILED! Error code: $LASTEXITCODE"
    Write-Host ""
    Write-Host "This means:"
    Write-Host "  - Payment method might not be set as default"
    Write-Host "  - Model access not fully enabled"
    Write-Host "  - Need to wait a few more minutes"
    Write-Host ""
    Write-Host "Don't worry - your system works fine with Gemini!"
}

# Cleanup
Remove-Item $tempFile -ErrorAction SilentlyContinue
Write-Host ""
