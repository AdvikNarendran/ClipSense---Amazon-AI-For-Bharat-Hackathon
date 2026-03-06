import os
import logging
import boto3
import json
import re
import time
import google.generativeai as genai
import whisper
from datetime import datetime, date
from botocore.exceptions import ClientError
from dotenv import load_dotenv
import tempfile
import urllib.parse

load_dotenv()

logger = logging.getLogger("clipsense.ai_engine")

class AIEngine:
    def __init__(self, gemini_api_key=None, whisper_model_name="base"):
        """
        Initializes the AIEngine with AWS clients and optional Gemini/Whisper configurations.
        Prioritizes AWS services (Bedrock, Transcribe) but can fall back to Gemini or local Whisper.
        """
        self.region = os.getenv("AWS_REGION", "us-east-1")
        self.gemini_api_key = gemini_api_key or os.getenv("GEMINI_API_KEY")
        self.whisper_model_name = whisper_model_name
        self.whisper_model = None
        
        # Pre-initialize model ID so it's ready
        self.bedrock_model_id = os.getenv("BEDROCK_MODEL_ID", "anthropic.claude-3-haiku-20240307-v1:0")

        # AWS clients will be initialized on-demand or by helpers.
        # Initializing them here for legacy compatibility if needed.
        self.transcribe = boto3.client('transcribe', region_name=self.region)
        self.bedrock = boto3.client('bedrock-runtime', region_name=self.region)
        self.rekognition = boto3.client('rekognition', region_name=self.region)
        
        logger.info("AIEngine initialized. AWS Mode: %s, Model: %s", bool(os.getenv("AWS_ACCESS_KEY_ID")), self.bedrock_model_id)

    def _download_s3_file(self, s3_uri):
        """Helper to download a file from S3 to a local temporary path."""
        try:
            parsed = urllib.parse.urlparse(s3_uri)
            bucket = parsed.netloc
            key = parsed.path.lstrip('/')
            
            temp_file = tempfile.NamedTemporaryFile(delete=False, suffix=os.path.splitext(key)[1])
            temp_path = temp_file.name
            temp_file.close()

            logger.info("Downloading %s from S3 to %s", s3_uri, temp_path)
            s3 = boto3.client('s3', region_name=self.region)
            s3.download_file(bucket, key, temp_path)
            return temp_path
        except Exception as e:
            logger.error("Failed to download S3 file for local processing: %s", e)
            return None

    def transcribe_video(self, video_source, task="transcribe"):
        """
        Transcribe video. Tries Amazon Transcribe first if it's an S3 URI, 
        otherwise falls back to local Whisper.
        """
        temp_local_path = None
        
        # 1. Try Amazon Transcribe if it's an S3 source
        if str(video_source).startswith("s3://"):
            try:
                # We need a job name for Transcribe
                job_name = f"transcription_{int(time.time())}"
                logger.info("Attempting Amazon Transcribe for: %s (Job: %s)", video_source, job_name)
                
                self.transcribe.start_transcription_job(
                    TranscriptionJobName=job_name,
                    Media={'MediaFileUri': video_source},
                    MediaFormat=video_source.split('.')[-1],
                    IdentifyLanguage=True
                )
                
                # Polling for completion
                while True:
                    status_resp = self.transcribe.get_transcription_job(TranscriptionJobName=job_name)
                    status = status_resp['TranscriptionJob']['TranscriptionJobStatus']
                    if status in ['COMPLETED', 'FAILED']:
                        break
                    time.sleep(5)
                
                if status == 'COMPLETED':
                    transcript_uri = status_resp['TranscriptionJob']['Transcript']['TranscriptFileUri']
                    # Note: Transcribe result is a JSON file content, Whisper returns segments.
                    # For consistency, it might be better to stay with Whisper for complex flows 
                    # unless we want to rebuild the segment parser for Transcribe.
                    # For now, let's treat Transcribe failure or non-segments as a reason to use Whisper.
                    logger.info("Transcribe completed. Note: results need parsing to match Whisper format.")
                    # If we really want Transcribe, we'd fetch the JSON and transform it here.
                    # Since Whisper is already working locally and well-integrated, let's prioritize the Whisper segments.
                    raise Exception("Transcribe results need manual mapping; falling back to Whisper for segment extraction.")

            except Exception as e:
                logger.warning("Amazon Transcribe flow bypassed or failed: %s. Falling back to local Whisper.", e)
                # Download for local Whisper
                temp_local_path = self._download_s3_file(video_source)
                video_source = temp_local_path or video_source

        # 2. Fallback to Local Whisper
        try:
            logger.info("Using local Whisper for transcription...")
            if not self.whisper_model:
                self.whisper_model = whisper.load_model(self.whisper_model_name)
            
            result = self.whisper_model.transcribe(video_source, task=task)
            return result
        finally:
            # Clean up temp file if created
            if temp_local_path and os.path.exists(temp_local_path):
                try:
                    os.remove(temp_local_path)
                    logger.info("Cleaned up temporary file: %s", temp_local_path)
                except Exception as e:
                    logger.error("Failed to cleanup temp file %s: %s", temp_local_path, e)

    def analyze_visuals(self, s3_uri):
        """Analyze video visuals using Amazon Rekognition to identify scene changes."""
        if not s3_uri.startswith("s3://"):
            logger.warning("Rekognition only supports S3 URIs. Skipping visual analysis.")
            return None
            
        try:
            parsed = urllib.parse.urlparse(s3_uri)
            bucket = parsed.netloc
            key = parsed.path.lstrip('/')
            
            logger.info("Starting Rekognition segment detection for: %s", s3_uri)
            response = self.rekognition.start_segment_detection(
                Video={'S3Object': {'Bucket': bucket, 'Name': key}},
                SegmentTypes=['SHOT']
            )
            job_id = response['JobId']
            
            # Polling for completion (Rekognition jobs are usually fast for segments)
            while True:
                status_resp = self.rekognition.get_segment_detection(JobId=job_id)
                status = status_resp['JobStatus']
                if status in ['SUCCEEDED', 'FAILED']:
                    break
                time.sleep(5)
                
            if status == 'SUCCEEDED':
                logger.info("Rekognition visual analysis completed.")
                return status_resp.get('Segments', [])
            else:
                logger.warning("Rekognition visual analysis failed.")
                return None
                
        except Exception as e:
            logger.error("Rekognition visual analysis error: %s", e)
            return None

    def generate_text(self, prompt):
        """Public method for text generation with multi-provider fallback."""
        return self._generate_with_fallback(prompt)

    def _generate_with_fallback(self, prompt):
        """Internal helper to try Bedrock, then Gemini."""
        # 1. Try Bedrock (Claude 3 Haiku)
        if os.getenv("AWS_ACCESS_KEY_ID") or os.getenv("AWS_PROFILE"):
            try:
                # Use Llama 3 or Titan if you want to avoid the Anthropic use case form
                model_id = self.bedrock_model_id
                logger.info("Attempting Bedrock (%s) generation...", model_id)
                
                if "anthropic" in model_id:
                    body_dict = {
                        "anthropic_version": "bedrock-2023-05-31",
                        "max_tokens": 1000,
                        "messages": [
                            {"role": "user", "content": [{"type": "text", "text": prompt}]}
                        ],
                        "temperature": 0.7
                    }
                elif "meta" in model_id:
                    body_dict = {
                        "prompt": f"<|begin_of_text|><|start_header_id|>user<|end_header_id|>\n\n{prompt}<|eot_id|><|start_header_id|>assistant<|end_header_id|>\n\n",
                        "max_gen_len": 1000,
                        "temperature": 0.5
                    }
                else: # Default for Amazon Titan
                    body_dict = {
                        "inputText": prompt,
                        "textGenerationConfig": {
                            "maxTokenCount": 512,
                            "stopSequences": [],
                            "temperature": 0.7,
                            "topP": 0.9
                        }
                    }

                response = self.bedrock.invoke_model(
                    modelId=model_id,
                    body=json.dumps(body_dict)
                )
                
                response_content = response['body'].read().decode('utf-8')
                res = json.loads(response_content)
                
                if "anthropic" in model_id:
                    return res['content'][0]['text']
                elif "meta" in model_id:
                    return res['generation']
                else: # Titan
                    return res['results'][0]['outputText']
                    
            except Exception as e:
                logger.warning("Bedrock generation failed: %s. Falling back to Gemini.", e)

        # 2. Try Gemini with multiple models
        if self.gemini_api_key:
            models = [
                'models/gemini-3.1-flash-lite-preview',
                'models/gemini-3.0-flash',
                'models/gemini-3.0-pro',
                'models/gemini-2.0-flash',
                'models/gemini-3-pro-preview',
                'models/gemini-flash-latest',
            ]
            
            last_error = None
            for model_name in models:
                try:
                    logger.info("Trying Gemini model: %s", model_name)
                    model = genai.GenerativeModel(model_name)
                    response = model.generate_content(prompt)
                    logger.info("Successfully generated content with model: %s", model_name)
                    return response.text
                except Exception as e:
                    logger.warning("Model %s failed: %s", model_name, e)
                    last_error = e
                    continue

        raise Exception(f"All AI generation failed. Last Gemini error: {last_error}")

    def analyze_transcription_with_timestamps(self, segments, visual_data=None, num_clips=3, max_duration=60):
        """Analyze subtitles with optional visual metadata and return clip ideas."""
        if not segments:
            return []

        total_duration = segments[-1]["end"] if segments else 0
        # Limit segments to avoid context window issues
        context_window = segments[:400] if len(segments) > 400 else segments
        
        context_str = "\n".join([f"ID:{i} [{s['start']:.1f}-{s['end']:.1f}] {s['text']}" for i, s in enumerate(context_window)])
        
        visual_metadata = ""
        if visual_data:
            visual_metadata = "\nVISUAL SCENE DATA (AWS Rekognition):\n"
            for seg in visual_data[:50]: # First 50 scene changes
                start = seg['StartTimestampMillis'] / 1000
                end = seg['EndTimestampMillis'] / 1000
                visual_metadata += f"- Scene change detected at approx {start:.1f}s to {end:.1f}s\n"

        prompt = f"""
Analyze the following video transcript segments (ID, Timestamps, Text) and identify the {num_clips} BEST potential viral clips from the ENTIRE video.
System Instruction: You are a professional video analyst. Your task is to identify the most engaging and high-impact moments from the provided transcript for social media clips. 

The video is {total_duration:.0f} seconds long. Analyze the ENTIRE transcript and select the highest-scoring moments from any part of the duration.
{visual_metadata}
Clip Length: 10 to {max_duration} seconds.
Selection Criteria: High emotional impact, professional insight, humor, or strong thematic importance.

Transcript:
{context_str}

Return valid JSON ONLY.
Format:
[
    {{
        "start_time": 10.5,
        "end_time": 25.0,
        "viral_score": 85,
        "hook_title": "Professional and engaging title",
        "caption": "Professional summary of the clip",
        "summary": "Full context of the moment",
        "hashtags": "#professional #insight"
    }}
]

STRICT RULES:
- "viral_score" MUST be an integer between 0 and 100.
- Use professional, appropriate language in all titles and captions.
- Ensure JSON is valid and properly formatted.
- Return EXACTLY {num_clips} objects.
"""
        
        try:
            text_response = self._generate_with_fallback(prompt)
            # Robust JSON extraction
            match = re.search(r'\[\s*\{.*\}\s*\]', text_response, re.DOTALL)
            if match:
                text_response = match.group(0)
            
            # Additional safety: strip markdown if regex didn't catch everything
            text_response = text_response.replace('```json', '').replace('```', '').strip()
            
            clips = json.loads(text_response)
            
            # Basic validation and default values
            for clip in clips:
                if "viral_score" not in clip: clip["viral_score"] = 75
                if "hook_title" not in clip: clip["hook_title"] = "Great Clip"
                if "caption" not in clip: clip["caption"] = clip.get("summary", "")
                if "hashtags" not in clip: clip["hashtags"] = "#viral #clipsense"
            
            return clips
            
        except Exception as e:
            logger.error("Error in AI analysis fallback flow: %s", e, exc_info=True)
            return [
                {
                    "start_time": 0, 
                    "end_time": min(15, total_duration), 
                    "viral_score": 50,
                    "hook_title": "Video Highlight", 
                    "caption": "Interesting moment from the video.",
                    "summary": "Fallback clip due to analysis timeout.", 
                    "hashtags": "#video #highlight"
                }
            ]

