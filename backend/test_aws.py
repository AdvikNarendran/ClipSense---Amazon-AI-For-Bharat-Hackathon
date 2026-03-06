import boto3
import os
from dotenv import load_dotenv

load_dotenv()

def test_aws_connection():
    print("🔍 Testing AWS Connection for ClipSense...")
    
    region = os.getenv("AWS_REGION", "us-east-1")
    access_key = os.getenv("AWS_ACCESS_KEY_ID")
    
    if not access_key:
        print("❌ ERROR: AWS_ACCESS_KEY_ID not found in .env file.")
        return

    print(f"✅ Credentials found for Region: {region}")

    # 1. Test S3
    try:
        s3 = boto3.client('s3')
        bucket = os.getenv("AWS_S3_BUCKET")
        s3.head_bucket(Bucket=bucket)
        print(f"✅ S3: Successfully connected to bucket '{bucket}'")
    except Exception as e:
        print(f"❌ S3 ERROR: {e}")

    # 2. Test DynamoDB
    try:
        db = boto3.resource('dynamodb', region_name=region)
        table_name = os.getenv("DYNAMO_PROJECTS_TABLE")
        table = db.Table(table_name)
        table.table_status
        print(f"✅ DynamoDB: Successfully connected to table '{table_name}'")
    except Exception as e:
        print(f"❌ DynamoDB ERROR: {e}")

    # 3. Test Bedrock
    try:
        bedrock = boto3.client('bedrock-runtime', region_name=region)
        # Simple test call
        bedrock.invoke_model(
            modelId="anthropic.claude-3-haiku-20240307-v1:0",
            body='{"anthropic_version": "bedrock-2023-05-31", "max_tokens": 10, "messages": [{"role": "user", "content": "hi"}]}'
        )
        print("✅ Bedrock: Successfully reached Claude 3 Haiku")
    except Exception as e:
        print(f"❌ Bedrock ERROR: Ensure you enabled 'Claude 3 Haiku' access in the Console. Error: {e}")

if __name__ == "__main__":
    test_aws_connection()
