$ErrorActionPreference = "Stop"

# Load environment variables
. "$PSScriptRoot\load-env.ps1"

$BUCKET_NAME = $env:AWS_S3_BUCKET
$AWS_REGION = $env:AWS_REGION
$AMPLIFY_DOMAIN = if ($env:AMPLIFY_DOMAIN) { $env:AMPLIFY_DOMAIN } else { "*.amplifyapp.com" }

if (-not $BUCKET_NAME) {
    Write-Host "Error: AWS_S3_BUCKET not set"
    exit 1
}

if (-not $AWS_REGION) {
    Write-Host "Error: AWS_REGION not set"
    exit 1
}

Write-Host "================================="
Write-Host "Setting up S3 bucket"
Write-Host "================================="
Write-Host "Bucket: $BUCKET_NAME"
Write-Host "Region: $AWS_REGION"
Write-Host ""

# Check if bucket exists
try {
    aws s3api head-bucket --bucket $BUCKET_NAME --region $AWS_REGION 2>$null
    Write-Host "Bucket already exists"
}
catch {
    Write-Host "Creating bucket..."

    if ($AWS_REGION -eq "us-east-1") {
        aws s3api create-bucket `
            --bucket $BUCKET_NAME
    }
    else {
        aws s3api create-bucket `
            --bucket $BUCKET_NAME `
            --region $AWS_REGION `
            --create-bucket-configuration LocationConstraint=$AWS_REGION
    }

    Write-Host "Bucket created"
}

# -----------------------------
# Block Public Access
# -----------------------------
Write-Host "Blocking public access..."

aws s3api put-public-access-block `
    --bucket $BUCKET_NAME `
    --public-access-block-configuration BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true `
    --region $AWS_REGION

Write-Host "Public access blocked"

# -----------------------------
# Enable Encryption
# -----------------------------
Write-Host "Enabling encryption..."

$encryptionConfig = @{
    Rules = @(
        @{
            ApplyServerSideEncryptionByDefault = @{
                SSEAlgorithm = "AES256"
            }
        }
    )
}

$encryptionFile = "$env:TEMP\encryption.json"

$encryptionConfig |
ConvertTo-Json -Depth 5 |
Out-File -Encoding utf8 $encryptionFile

aws s3api put-bucket-encryption `
    --bucket $BUCKET_NAME `
    --server-side-encryption-configuration file://$encryptionFile `
    --region $AWS_REGION

Write-Host "Encryption enabled (AES256)"

# -----------------------------
# Configure CORS
# -----------------------------
Write-Host "Configuring CORS..."

$corsConfig = @{
    CORSRules = @(
        @{
            AllowedHeaders = @("*")
            AllowedMethods = @("GET","PUT","POST","DELETE")
            AllowedOrigins = @(
                "https://$AMPLIFY_DOMAIN",
                "http://localhost:3000"
            )
            ExposeHeaders = @("ETag")
            MaxAgeSeconds = 3000
        }
    )
}

$corsFile = "$env:TEMP\cors.json"

$corsConfig |
ConvertTo-Json -Depth 5 |
Out-File -Encoding utf8 $corsFile

aws s3api put-bucket-cors `
    --bucket $BUCKET_NAME `
    --cors-configuration file://$corsFile `
    --region $AWS_REGION

Write-Host "CORS configured"

# -----------------------------
# Complete
# -----------------------------
Write-Host ""
Write-Host "================================="
Write-Host "S3 Setup Complete"
Write-Host "================================="
Write-Host "Bucket: $BUCKET_NAME"
Write-Host "Region: $AWS_REGION"
Write-Host "Encryption: AES256"
Write-Host "Public Access: Blocked"
Write-Host "CORS: Enabled"
Write-Host ""