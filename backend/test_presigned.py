import boto3
import os
from dotenv import load_dotenv
from botocore.client import Config

load_dotenv()

def test_presigned():
    region = os.getenv("AWS_REGION", "ap-south-1")
    bucket = os.getenv("AWS_S3_BUCKET")
    
    # Test with @ sign
    key = "clips/darkx4115@gmail.com/test_clip.mp4"
    
    s3 = boto3.client('s3', region_name=region, config=Config(signature_version='s3v4'))
    
    url = s3.generate_presigned_url(
        'get_object',
        Params={'Bucket': bucket, 'Key': key},
        ExpiresIn=3600
    )
    
    print(f"Key: {key}")
    print(f"URL: {url}")
    
    # Check if URL contains double encoding
    if "%2540" in url:
        print("⚠️ Warning: Double encoding detected (%2540)")
    elif "%40" in url:
        print("✅ Single encoding detected (%40)")
    else:
        print("❓ No encoding found for @")

if __name__ == "__main__":
    test_presigned()
