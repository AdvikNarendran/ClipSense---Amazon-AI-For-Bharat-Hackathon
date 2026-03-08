# Update Lambda environment variables to include email credentials

$ErrorActionPreference = "Stop"

# Load environment variables
. "$PSScriptRoot\backend\load-env.ps1"

$FUNCTION_NAME = "clipsense-api"
$AWS_REGION = $env:AWS_REGION

if (-not $env:SENDER_EMAIL) {
    Write-Host "Error: SENDER_EMAIL not set in backend/.env file" -ForegroundColor Red
    exit 1
}

if (-not $env:SENDER_PASSWORD) {
    Write-Host "Error: SENDER_PASSWORD not set in backend/.env file" -ForegroundColor Red
    exit 1
}

Write-Host "=========================================="
Write-Host "Updating Lambda Email Configuration"
Write-Host "=========================================="
Write-Host "Function: $FUNCTION_NAME"
Write-Host "Region: $AWS_REGION"
Write-Host "Sender Email: $($env:SENDER_EMAIL)"
Write-Host ""

# Get current environment variables
Write-Host "Fetching current Lambda configuration..."
$currentEnv = aws lambda get-function-configuration `
    --function-name $FUNCTION_NAME `
    --region $AWS_REGION `
    --query "Environment.Variables" `
    --output json | ConvertFrom-Json

# Add email credentials
$currentEnv | Add-Member -NotePropertyName "SENDER_EMAIL" -NotePropertyValue $env:SENDER_EMAIL -Force
$currentEnv | Add-Member -NotePropertyName "SENDER_PASSWORD" -NotePropertyValue $env:SENDER_PASSWORD -Force

# Convert back to comma-separated format
$envVars = ($currentEnv.PSObject.Properties | ForEach-Object { "$($_.Name)=$($_.Value)" }) -join ","

Write-Host "Updating Lambda environment variables..."
aws lambda update-function-configuration `
    --function-name $FUNCTION_NAME `
    --region $AWS_REGION `
    --environment "Variables={$envVars}" `
    --output json | Out-Null

if ($LASTEXITCODE -eq 0) {
    Write-Host ""
    Write-Host "Lambda email configuration updated successfully" -ForegroundColor Green
    Write-Host ""
    Write-Host "Email credentials added:"
    Write-Host "  SENDER_EMAIL: $($env:SENDER_EMAIL)"
    Write-Host "  SENDER_PASSWORD: ********"
    Write-Host ""
    Write-Host "OTP emails will now be sent from Lambda."
} else {
    Write-Host ""
    Write-Host "Failed to update Lambda configuration" -ForegroundColor Red
    exit 1
}
