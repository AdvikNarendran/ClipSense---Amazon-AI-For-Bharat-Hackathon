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

    def analyze_with_bedrock(self, prompt, model_id="global.anthropic.claude-haiku-4-5-20251001-v1:0"):
        """Use Amazon Bedrock (Claude Haiku for cost-efficiency) to analyze text"""
        try:
            response = self.bedrock.invoke_model(
                modelId=model_id,
                body=f"{{ \"prompt\": \"{prompt}\", \"max_tokens\": 1000, \"temperature\": 0.7 }}"
            )
            return response['body'].read().decode('utf-8')
        except ClientError as e:
            logger.error(f"Bedrock Error: {e}")
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
