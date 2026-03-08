#!/usr/bin/env python3
"""
Test AWS Bedrock Claude 3 Haiku Access
"""

import json
import boto3
from botocore.exceptions import ClientError

def test_bedrock():
    print("=" * 60)
    print("Testing AWS Bedrock Claude 3 Haiku Access")
    print("=" * 60)
    print()
    
    # Initialize Bedrock client
    try:
        bedrock = boto3.client(
            service_name='bedrock-runtime',
            region_name='ap-south-1'
        )
        print("✅ Bedrock client initialized")
    except Exception as e:
        print(f"❌ Failed to initialize Bedrock client: {e}")
        return False
    
    # Prepare the request
    model_id = "anthropic.claude-3-haiku-20240307-v1:0"
    
    request_body = {
        "anthropic_version": "bedrock-2023-05-31",
        "max_tokens": 100,
        "messages": [
            {
                "role": "user",
                "content": "Say hello in one sentence"
            }
        ]
    }
    
    print(f"Model ID: {model_id}")
    print(f"Request: {json.dumps(request_body, indent=2)}")
    print()
    print("Invoking model...")
    print()
    
    # Invoke the model
    try:
        response = bedrock.invoke_model(
            modelId=model_id,
            body=json.dumps(request_body)
        )
        
        # Parse response
        response_body = json.loads(response['body'].read())
        
        print("=" * 60)
        print("✅ SUCCESS! Bedrock is working!")
        print("=" * 60)
        print()
        print("Response:")
        print(json.dumps(response_body, indent=2))
        print()
        
        # Extract the actual message
        if 'content' in response_body and len(response_body['content']) > 0:
            message = response_body['content'][0].get('text', '')
            print("Claude's Response:")
            print(f"  {message}")
            print()
        
        print("=" * 60)
        print("✅ Bedrock is Ready!")
        print("=" * 60)
        print()
        print("Your EC2 worker will automatically use Bedrock now.")
        print("No changes needed - just upload a video!")
        print()
        
        return True
        
    except ClientError as e:
        error_code = e.response['Error']['Code']
        error_message = e.response['Error']['Message']
        
        print("=" * 60)
        print("❌ Bedrock Access Issue")
        print("=" * 60)
        print()
        print(f"Error Code: {error_code}")
        print(f"Error Message: {error_message}")
        print()
        
        if 'AccessDeniedException' in error_code:
            print("Issue: Model access not enabled or payment method issue")
            print()
            print("Solutions:")
            print("1. Go to: https://console.aws.amazon.com/bedrock/home?region=ap-south-1#/modelaccess")
            print("2. Click 'Manage model access'")
            print("3. Enable 'Claude 3 Haiku'")
            print("4. Ensure payment method is set as default")
            print("5. Wait 2-5 minutes and try again")
        elif 'ValidationException' in error_code:
            print("Issue: Request format problem")
            print("This is unusual - the request format should be correct")
        else:
            print("Issue: Unknown error")
            print("Check AWS Console for more details")
        
        print()
        print("Don't worry - your system works perfectly with Gemini!")
        print()
        
        return False
        
    except Exception as e:
        print(f"❌ Unexpected error: {e}")
        print()
        print("Don't worry - your system works perfectly with Gemini!")
        print()
        return False

if __name__ == "__main__":
    test_bedrock()
