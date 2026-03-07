import os
import boto3
import logging
from botocore.exceptions import ClientError
from dotenv import load_dotenv

load_dotenv()

logger = logging.getLogger("clipsense.aws")

from botocore.client import Config

class S3Storage:
    def __init__(self):
        self.region = os.getenv("AWS_REGION", "ap-south-1")
        self.bucket_name = os.getenv("AWS_S3_BUCKET")
        # Force SigV4 and regional addressing for S3 (critical for ap-south-1)
        self.s3_client = boto3.client(
            's3', 
            region_name=self.region,
            config=Config(signature_version='s3v4', s3={'addressing_style': 'virtual'})
        )

    def upload_file(self, file_path, object_name=None):
        """Upload to S3, fallback to local path on failure."""
        if object_name is None:
            object_name = os.path.basename(file_path)

        if os.getenv("AWS_ACCESS_KEY_ID") or os.getenv("AWS_PROFILE"):
            try:
                self.s3_client.upload_file(file_path, self.bucket_name, object_name)
                logger.info(f"File {file_path} uploaded to {self.bucket_name}/{object_name}")
                return f"s3://{self.bucket_name}/{object_name}"
            except Exception as e:
                logger.warning(f"S3 Upload failed: {e}. Falling back to local path.")
        
        # Fallback: Just return the local path (or a simulated local URI)
        return f"local://{object_name}"

    def get_presigned_url(self, object_name, expiration=3600):
        """Generate presigned URL, fallback to local server URL on failure."""
        if os.getenv("AWS_ACCESS_KEY_ID") or os.getenv("AWS_PROFILE"):
            try:
                return self.s3_client.generate_presigned_url(
                    'get_object', Params={'Bucket': self.bucket_name, 'Key': object_name},
                    ExpiresIn=expiration
                )
            except Exception as e:
                logger.warning(f"S3 Presigned URL failed: {e}. Falling back to local.")

        # Fallback: Return a path that the local Flask server can handle (e.g., via a /static/ or /downloads/ route)
        # Note: server.py needs to handle 'local://' or these relative paths.
        return f"/api/projects/download_local/{object_name}"

    def delete_prefix(self, prefix):
        """Delete all objects with a specific prefix from S3."""
        if not (os.getenv("AWS_ACCESS_KEY_ID") or os.getenv("AWS_PROFILE")):
            logger.info("Local mode: Skipping S3 delete_prefix for %s", prefix)
            return

        try:
            # List all objects with prefix
            response = self.s3_client.list_objects_v2(Bucket=self.bucket_name, Prefix=prefix)
            if 'Contents' in response:
                delete_keys = {'Objects': [{'Key': obj['Key']} for obj in response['Contents']]}
                self.s3_client.delete_objects(Bucket=self.bucket_name, Delete=delete_keys)
                logger.info("Deleted S3 prefix: %s (%d objects)", prefix, len(response['Contents']))
        except Exception as e:
            logger.error("S3 delete_prefix error for %s: %s", prefix, e)

class AWSAIEngine:
    def __init__(self):
        self.region = os.getenv("AWS_REGION", "ap-south-1")
        config = Config(region_name=self.region, signature_version='s3v4')
        self.transcribe = boto3.client('transcribe', config=config)
        self.bedrock = boto3.client('bedrock-runtime', config=config)
        self.rekognition = boto3.client('rekognition', config=config)
        self.comprehend = boto3.client('comprehend', config=config)

    def start_transcription(self, job_name, s3_uri):
        """Start an Amazon Transcribe job"""
        try:
            self.transcribe.start_transcription_job(
                TranscriptionJobName=job_name,
                Media={'MediaFileUri': s3_uri},
                MediaFormat=s3_uri.split('.')[-1],
                IdentifyLanguage=True
            )
            return True
        except ClientError as e:
            logger.error(f"Transcribe Error: {e}")
            return False

    def get_transcription_result(self, job_name):
        """Poll and get the result of a transcription job"""
        try:
            job = self.transcribe.get_transcription_job(TranscriptionJobName=job_name)
            status = job['TranscriptionJob']['TranscriptionJobStatus']
            if status == 'COMPLETED':
                return job['TranscriptionJob']['Transcript']['TranscriptFileUri']
            return status
        except ClientError as e:
            logger.error(f"Transcribe Job Fetch Error: {e}")
            return None

    def analyze_with_bedrock(self, prompt, model_id=None):
        """Use Amazon Bedrock (Claude) to analyze text, fallback to Gemini if Bedrock fails"""
        if model_id is None:
            model_id = os.getenv("BEDROCK_MODEL_ID", "anthropic.claude-3-haiku-20240307-v1:0")
        
        try:
            # Prepare request body for Claude 3
            request_body = {
                "anthropic_version": "bedrock-2023-05-31",
                "max_tokens": 2000,
                "temperature": 0.7,
                "messages": [
                    {
                        "role": "user",
                        "content": prompt
                    }
                ]
            }
            
            import json
            response = self.bedrock.invoke_model(
                modelId=model_id,
                body=json.dumps(request_body)
            )
            
            # Parse response
            response_body = json.loads(response['body'].read())
            
            # Extract text from Claude 3 response format
            if 'content' in response_body and len(response_body['content']) > 0:
                logger.info("Bedrock analysis successful")
                return response_body['content'][0]['text']
            
            logger.warning("Unexpected Bedrock response format, falling back to Gemini")
            return self._fallback_to_gemini(prompt)
            
        except ClientError as e:
            logger.error(f"Bedrock Error: {e}, falling back to Gemini")
            return self._fallback_to_gemini(prompt)
        except Exception as e:
            logger.error(f"Bedrock Unexpected Error: {e}, falling back to Gemini")
            return self._fallback_to_gemini(prompt)
    
    def _fallback_to_gemini(self, prompt):
        """Fallback to Google Gemini API when Bedrock fails"""
        gemini_api_key = os.getenv("GEMINI_API_KEY")
        if not gemini_api_key:
            logger.error("GEMINI_API_KEY not set, cannot fallback")
            return None
        
        try:
            import google.generativeai as genai
            
            # Configure Gemini
            genai.configure(api_key=gemini_api_key)
            
            # Try models in order of preference
            usable_text_models = [
                "models/gemini-3.1-flash-lite-preview",
                "models/gemini-3-flash-preview",

                "models/gemma-3-1b-it",
                "models/gemma-3-4b-it",
                "models/gemma-3-12b-it",
                "models/gemma-3-27b-it",
                "models/gemma-3n-e2b-it",
                "models/gemma-3n-e4b-it"
            ]
            
            for model_name in usable_models:
                try:
                    model = genai.GenerativeModel(model_name)
                    response = model.generate_content(prompt)
                    
                    if response and response.text:
                        logger.info(f"Gemini fallback successful with model: {model_name}")
                        return response.text
                except Exception as model_error:
                    logger.warning(f"Gemini model {model_name} failed: {model_error}")
                    continue
            
            logger.error("All Gemini models failed")
            return None
            
        except ImportError:
            logger.error("google-generativeai package not installed")
            return None
        except Exception as e:
            logger.error(f"Gemini fallback error: {e}")
            return None

    def start_video_analysis(self, bucket, key):
        """Start Rekognition segment detection to find scene changes."""
        try:
            response = self.rekognition.start_segment_detection(
                Video={'S3Object': {'Bucket': bucket, 'Name': key}},
                SegmentTypes=['SHOT']
            )
            return response['JobId']
        except ClientError as e:
            logger.error(f"Rekognition Start Error: {e}")
            return None

    def get_video_analysis(self, job_id):
        """Get results of Rekognition segment detection."""
        try:
            response = self.rekognition.get_segment_detection(JobId=job_id)
            status = response['JobStatus']
            if status == 'SUCCEEDED':
                return response['Segments']
            return status
        except ClientError as e:
            logger.error(f"Rekognition Get Error: {e}")
            return None

# Global instances
s3_storage = S3Storage()
aws_ai = AWSAIEngine()
