#!/bin/bash
# Setup S3 bucket for ClipSense storage

set -e

BUCKET_NAME="${AWS_S3_BUCKET:-clipsense-storage}"
AWS_REGION="${AWS_REGION:-ap-south-1}"
AMPLIFY_DOMAIN="${AMPLIFY_DOMAIN:-*.amplifyapp.com}"

echo "=========================================="
echo "Setting up S3 Bucket"
echo "=========================================="
echo "Bucket Name: $BUCKET_NAME"
echo "Region: $AWS_REGION"
echo ""

# Check if bucket exists
if aws s3api head-bucket --bucket "$BUCKET_NAME" --region "$AWS_REGION" 2>/dev/null; then
    echo "✓ Bucket already exists: $BUCKET_NAME"
else
    echo "Creating S3 bucket..."
    if [ "$AWS_REGION" == "us-east-1" ]; then
        aws s3api create-bucket \
            --bucket "$BUCKET_NAME" \
            --region "$AWS_REGION"
    else
        aws s3api create-bucket \
            --bucket "$BUCKET_NAME" \
            --region "$AWS_REGION" \
            --create-bucket-configuration LocationConstraint="$AWS_REGION"
    fi
    echo "✓ Bucket created: $BUCKET_NAME"
fi

# Block public access
echo "Configuring public access block..."
aws s3api put-public-access-block \
    --bucket "$BUCKET_NAME" \
    --public-access-block-configuration \
        "BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true" \
    --region "$AWS_REGION"
echo "✓ Public access blocked"

# Enable server-side encryption
echo "Enabling server-side encryption..."
aws s3api put-bucket-encryption \
    --bucket "$BUCKET_NAME" \
    --server-side-encryption-configuration '{
        "Rules": [{
            "ApplyServerSideEncryptionByDefault": {
                "SSEAlgorithm": "AES256"
            }
        }]
    }' \
    --region "$AWS_REGION"
echo "✓ Encryption enabled (AES-256)"

# Configure CORS
echo "Configuring CORS..."
cat > /tmp/cors-config.json <<EOF
{
  "CORSRules": [
    {
      "AllowedHeaders": ["*"],
      "AllowedMethods": ["GET", "PUT", "POST", "DELETE"],
      "AllowedOrigins": ["https://$AMPLIFY_DOMAIN", "http://localhost:3000"],
      "ExposeHeaders": ["ETag"],
      "MaxAgeSeconds": 3000
    }
  ]
}
EOF

aws s3api put-bucket-cors \
    --bucket "$BUCKET_NAME" \
    --cors-configuration file:///tmp/cors-config.json \
    --region "$AWS_REGION"
echo "✓ CORS configured"

echo ""
echo "=========================================="
echo "S3 Bucket Setup Complete"
echo "=========================================="
echo "Bucket: $BUCKET_NAME"
echo "Region: $AWS_REGION"
echo "Encryption: AES-256"
echo "Public Access: Blocked"
echo "CORS: Configured for $AMPLIFY_DOMAIN"
echo ""
echo "Add this to your environment variables:"
echo "  export AWS_S3_BUCKET=\"$BUCKET_NAME\""
