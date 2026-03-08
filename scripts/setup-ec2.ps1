# Setup EC2 worker instance for ClipSense

$ErrorActionPreference = "Stop"

. "$PSScriptRoot\load-env.ps1"

$INSTANCE_NAME = "clipsense-worker"
$ROLE_NAME = "ClipSenseEC2WorkerRole"
$SECURITY_GROUP_NAME = "clipsense-worker-sg"

$AWS_REGION = $env:AWS_REGION
$AWS_ACCOUNT_ID = aws sts get-caller-identity --query Account --output text

$KEY_NAME = $env:EC2_KEY_NAME
$GITHUB_REPO = $env:GITHUB_REPO

Write-Host "======================================"
Write-Host "Setting up EC2 Worker"
Write-Host "======================================"

# Get queue
$SQS_QUEUE_URL = aws sqs get-queue-url `
--queue-name clipsense-processing-queue `
--region $AWS_REGION `
--query "QueueUrl" `
--output text

# ---------------------------
# IAM Role
# ---------------------------

try {

$ROLE_ARN = aws iam get-role `
--role-name $ROLE_NAME `
--query "Role.Arn" `
--output text 2>$null

Write-Host "IAM role exists"

}
catch {

Write-Host "Creating IAM role"

$trustPolicy=@"
{
 "Version":"2012-10-17",
 "Statement":[
  {
   "Effect":"Allow",
   "Principal":{"Service":"ec2.amazonaws.com"},
   "Action":"sts:AssumeRole"
  }
 ]
}
"@

$trustFile="$env:TEMP\ec2-trust.json"

$trustPolicy | Out-File $trustFile -Encoding ascii

aws iam create-role `
--role-name $ROLE_NAME `
--assume-role-policy-document file://$trustFile

aws iam create-instance-profile `
--instance-profile-name $ROLE_NAME

aws iam add-role-to-instance-profile `
--instance-profile-name $ROLE_NAME `
--role-name $ROLE_NAME

}

# ---------------------------
# Security group
# ---------------------------

$VPC_ID = aws ec2 describe-vpcs `
--filters Name=isDefault,Values=true `
--query "Vpcs[0].VpcId" `
--output text `
--region $AWS_REGION

$SG_ID = aws ec2 describe-security-groups `
--filters Name=group-name,Values=$SECURITY_GROUP_NAME `
--query "SecurityGroups[0].GroupId" `
--output text `
--region $AWS_REGION

if ($SG_ID -eq "None") {

Write-Host "Creating security group"

$SG_ID = aws ec2 create-security-group `
--group-name $SECURITY_GROUP_NAME `
--description "ClipSense worker" `
--vpc-id $VPC_ID `
--region $AWS_REGION `
--query "GroupId" `
--output text

aws ec2 authorize-security-group-ingress `
--group-id $SG_ID `
--protocol tcp `
--port 22 `
--cidr 0.0.0.0/0 `
--region $AWS_REGION

}

# ---------------------------
# Get AMI
# ---------------------------

$AMI_ID = aws ec2 describe-images `
--owners amazon `
--filters Name=name,Values=al2023-ami-2023.* `
--query "Images | sort_by(@,&CreationDate)[-1].ImageId" `
--output text `
--region $AWS_REGION

Write-Host "Using AMI $AMI_ID"

# ---------------------------
# User Data Script (Bash)
# ---------------------------

$userDataScript=@"
#!/bin/bash

yum update -y
yum install -y docker git

systemctl start docker
systemctl enable docker

usermod -a -G docker ec2-user

cd /home/ec2-user

git clone https://github.com/$GITHUB_REPO.git clipsense

mkdir -p /etc/clipsense

cat > /etc/clipsense/.env <<EOF
AWS_REGION=$AWS_REGION
AWS_S3_BUCKET=$($env:AWS_S3_BUCKET)
DYNAMO_PROJECTS_TABLE=$($env:DYNAMO_PROJECTS_TABLE)
SQS_QUEUE_URL=$SQS_QUEUE_URL
GEMINI_API_KEY=$($env:GEMINI_API_KEY)
EOF

chmod 600 /etc/clipsense/.env

cd /home/ec2-user/clipsense/backend

docker build -f Dockerfile.worker -t clipsense-worker .

docker run -d \
 --name clipsense-worker \
 --restart unless-stopped \
 --env-file /etc/clipsense/.env \
 clipsense-worker

echo "Worker started"
"@

$USER_DATA=[Convert]::ToBase64String([System.Text.Encoding]::UTF8.GetBytes($userDataScript))

# ---------------------------
# Launch Instance
# ---------------------------

Write-Host "Launching EC2 instance..."

$INSTANCE_ID = aws ec2 run-instances `
--image-id $AMI_ID `
--instance-type t3.small `
--key-name $KEY_NAME `
--security-group-ids $SG_ID `
--iam-instance-profile Name=$ROLE_NAME `
--user-data $USER_DATA `
--region $AWS_REGION `
--tag-specifications "ResourceType=instance,Tags=[{Key=Name,Value=$INSTANCE_NAME}]" `
--query "Instances[0].InstanceId" `
--output text

Write-Host "Instance launched $INSTANCE_ID"

aws ec2 wait instance-running `
--instance-ids $INSTANCE_ID `
--region $AWS_REGION

$PUBLIC_IP = aws ec2 describe-instances `
--instance-ids $INSTANCE_ID `
--query "Reservations[0].Instances[0].PublicIpAddress" `
--output text `
--region $AWS_REGION

Write-Host ""
Write-Host "======================================"
Write-Host "Worker Ready"
Write-Host "======================================"
Write-Host "Instance: $INSTANCE_ID"
Write-Host "Public IP: $PUBLIC_IP"
Write-Host ""

Write-Host "SSH command:"
Write-Host "ssh -i ~/.ssh/$KEY_NAME.pem ec2-user@$PUBLIC_IP"