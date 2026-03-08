#!/bin/bash
# Setup EC2 worker instance for ClipSense video processing

set -e

INSTANCE_NAME="clipsense-worker"
ROLE_NAME="ClipSenseEC2WorkerRole"
SECURITY_GROUP_NAME="clipsense-worker-sg"
AWS_REGION="${AWS_REGION:-ap-south-1}"
AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
KEY_NAME="${EC2_KEY_NAME:-clipsense-worker-key}"

echo "=========================================="
echo "Setting up EC2 Worker Instance"
echo "=========================================="
echo "Instance Name: $INSTANCE_NAME"
echo "Region: $AWS_REGION"
echo "Key Name: $KEY_NAME"
echo ""

# Get SQS queue URL
SQS_QUEUE_URL=$(aws sqs get-queue-url --queue-name "clipsense-processing-queue" --region "$AWS_REGION" --query 'QueueUrl' --output text 2>/dev/null || echo "")

if [ -z "$SQS_QUEUE_URL" ]; then
    echo "Error: SQS queue not found. Run setup-sqs.sh first."
    exit 1
fi

# Create IAM role if it doesn't exist
ROLE_ARN=$(aws iam get-role --role-name "$ROLE_NAME" --query 'Role.Arn' --output text 2>/dev/null || echo "")

if [ -z "$ROLE_ARN" ]; then
    echo "Creating IAM role for EC2..."
    
    cat > /tmp/ec2-trust-policy.json <<EOF
{
  "Version": "2012-10-17",
  "Statement": [{
    "Effect": "Allow",
    "Principal": {"Service": "ec2.amazonaws.com"},
    "Action": "sts:AssumeRole"
  }]
}
EOF
    
    ROLE_ARN=$(aws iam create-role \
        --role-name "$ROLE_NAME" \
        --assume-role-policy-document file:///tmp/ec2-trust-policy.json \
        --query 'Role.Arn' \
        --output text)
    
    echo "✓ Role created: $ROLE_ARN"
    
    # Custom policy for S3, DynamoDB, SQS, Bedrock, Transcribe, Rekognition
    cat > /tmp/ec2-policy.json <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "s3:GetObject",
        "s3:PutObject",
        "s3:DeleteObject",
        "s3:ListBucket"
      ],
      "Resource": [
        "arn:aws:s3:::*",
        "arn:aws:s3:::*/*"
      ]
    },
    {
      "Effect": "Allow",
      "Action": [
        "dynamodb:GetItem",
        "dynamodb:UpdateItem",
        "dynamodb:Query"
      ],
      "Resource": "arn:aws:dynamodb:${AWS_REGION}:${AWS_ACCOUNT_ID}:table/ClipSense*"
    },
    {
      "Effect": "Allow",
      "Action": [
        "sqs:ReceiveMessage",
        "sqs:DeleteMessage",
        "sqs:GetQueueAttributes"
      ],
      "Resource": "arn:aws:sqs:${AWS_REGION}:${AWS_ACCOUNT_ID}:clipsense-*"
    },
    {
      "Effect": "Allow",
      "Action": [
        "bedrock:InvokeModel"
      ],
      "Resource": "arn:aws:bedrock:${AWS_REGION}::foundation-model/*"
    },
    {
      "Effect": "Allow",
      "Action": [
        "transcribe:StartTranscriptionJob",
        "transcribe:GetTranscriptionJob"
      ],
      "Resource": "*"
    },
    {
      "Effect": "Allow",
      "Action": [
        "rekognition:StartSegmentDetection",
        "rekognition:GetSegmentDetection"
      ],
      "Resource": "*"
    }
  ]
}
EOF
    
    aws iam put-role-policy \
        --role-name "$ROLE_NAME" \
        --policy-name "ClipSenseEC2WorkerPolicy" \
        --policy-document file:///tmp/ec2-policy.json
    
    echo "✓ Policies attached"
    
    # Create instance profile
    aws iam create-instance-profile --instance-profile-name "$ROLE_NAME" 2>/dev/null || echo "✓ Instance profile exists"
    aws iam add-role-to-instance-profile --instance-profile-name "$ROLE_NAME" --role-name "$ROLE_NAME" 2>/dev/null || echo "✓ Role already in profile"
    
    echo "Waiting 10 seconds for IAM role to propagate..."
    sleep 10
else
    echo "✓ IAM role already exists: $ROLE_ARN"
fi

# Create security group
VPC_ID=$(aws ec2 describe-vpcs --region "$AWS_REGION" --filters "Name=isDefault,Values=true" --query 'Vpcs[0].VpcId' --output text)
SG_ID=$(aws ec2 describe-security-groups \
    --region "$AWS_REGION" \
    --filters "Name=group-name,Values=$SECURITY_GROUP_NAME" \
    --query 'SecurityGroups[0].GroupId' \
    --output text 2>/dev/null || echo "")

if [ -z "$SG_ID" ] || [ "$SG_ID" == "None" ]; then
    echo "Creating security group..."
    SG_ID=$(aws ec2 create-security-group \
        --group-name "$SECURITY_GROUP_NAME" \
        --description "Security group for ClipSense worker" \
        --vpc-id "$VPC_ID" \
        --region "$AWS_REGION" \
        --query 'GroupId' \
        --output text)
    
    # Allow SSH from anywhere (restrict this in production)
    aws ec2 authorize-security-group-ingress \
        --group-id "$SG_ID" \
        --protocol tcp \
        --port 22 \
        --cidr 0.0.0.0/0 \
        --region "$AWS_REGION"
    
    echo "✓ Security group created: $SG_ID"
else
    echo "✓ Security group already exists: $SG_ID"
fi

# Get latest Amazon Linux 2023 AMI
AMI_ID=$(aws ec2 describe-images \
    --region "$AWS_REGION" \
    --owners amazon \
    --filters "Name=name,Values=al2023-ami-2023.*-x86_64" "Name=state,Values=available" \
    --query 'sort_by(Images, &CreationDate)[-1].ImageId' \
    --output text)

echo "Using AMI: $AMI_ID"
echo ""

# Create user data script
cat > /tmp/user-data.sh <<'EOF'
#!/bin/bash
yum update -y
yum install -y docker git
systemctl start docker
systemctl enable docker
usermod -a -G docker ec2-user

cd /home/ec2-user
git clone https://github.com/${GITHUB_REPO:-yourusername/clipsense}.git
chown -R ec2-user:ec2-user clipsense

mkdir -p /etc/clipsense
cat > /etc/clipsense/.env <<ENVEOF
AWS_REGION=${AWS_REGION}
AWS_S3_BUCKET=${AWS_S3_BUCKET}
DYNAMO_PROJECTS_TABLE=ClipSenseProjects
SQS_QUEUE_URL=${SQS_QUEUE_URL}
GEMINI_API_KEY=${GEMINI_API_KEY}
ENVEOF
chmod 600 /etc/clipsense/.env

cd /home/ec2-user/clipsense/backend
docker build -f Dockerfile.worker -t clipsense-worker .
docker run -d \
  --name clipsense-worker \
  --restart unless-stopped \
  --env-file /etc/clipsense/.env \
  clipsense-worker

echo "ClipSense worker deployed successfully"
EOF

# Substitute environment variables in user data
export AWS_REGION SQS_QUEUE_URL
export AWS_S3_BUCKET="${AWS_S3_BUCKET:-clipsense-storage}"
export GEMINI_API_KEY="${GEMINI_API_KEY:-}"
export GITHUB_REPO="${GITHUB_REPO:-yourusername/clipsense}"

USER_DATA=$(envsubst < /tmp/user-data.sh | base64 -w 0)

# Check if instance already exists
INSTANCE_ID=$(aws ec2 describe-instances \
    --region "$AWS_REGION" \
    --filters "Name=tag:Name,Values=$INSTANCE_NAME" "Name=instance-state-name,Values=running,pending,stopped" \
    --query 'Reservations[0].Instances[0].InstanceId' \
    --output text 2>/dev/null || echo "")

if [ -n "$INSTANCE_ID" ] && [ "$INSTANCE_ID" != "None" ]; then
    echo "✓ Instance already exists: $INSTANCE_ID"
    PUBLIC_IP=$(aws ec2 describe-instances \
        --instance-ids "$INSTANCE_ID" \
        --region "$AWS_REGION" \
        --query 'Reservations[0].Instances[0].PublicIpAddress' \
        --output text)
else
    echo "Launching EC2 instance..."
    INSTANCE_ID=$(aws ec2 run-instances \
        --image-id "$AMI_ID" \
        --instance-type t2.micro \
        --key-name "$KEY_NAME" \
        --security-group-ids "$SG_ID" \
        --iam-instance-profile "Name=$ROLE_NAME" \
        --user-data "$USER_DATA" \
        --region "$AWS_REGION" \
        --tag-specifications "ResourceType=instance,Tags=[{Key=Name,Value=$INSTANCE_NAME}]" \
        --query 'Instances[0].InstanceId' \
        --output text)
    
    echo "✓ Instance launched: $INSTANCE_ID"
    echo "Waiting for instance to start..."
    aws ec2 wait instance-running --instance-ids "$INSTANCE_ID" --region "$AWS_REGION"
    
    PUBLIC_IP=$(aws ec2 describe-instances \
        --instance-ids "$INSTANCE_ID" \
        --region "$AWS_REGION" \
        --query 'Reservations[0].Instances[0].PublicIpAddress' \
        --output text)
    
    echo "✓ Instance running"
fi

echo ""
echo "=========================================="
echo "EC2 Worker Setup Complete"
echo "=========================================="
echo "Instance ID: $INSTANCE_ID"
echo "Public IP: $PUBLIC_IP"
echo ""
echo "SSH into instance:"
echo "  ssh -i ~/.ssh/$KEY_NAME.pem ec2-user@$PUBLIC_IP"
echo ""
echo "Check worker logs:"
echo "  ssh -i ~/.ssh/$KEY_NAME.pem ec2-user@$PUBLIC_IP 'docker logs -f clipsense-worker'"
