"""
Flask REST API server for ClipSense AI.
Wraps the existing AI engine and video processor as HTTP endpoints
so the Next.js frontend can communicate with the backend.
"""

import os
import sys
import uuid
import json
import shutil
import logging
import threading
import time
import zipfile
import boto3
import tempfile
from io import BytesIO
from datetime import datetime

from flask import Flask, request, jsonify, send_file
from flask_cors import CORS
from dotenv import load_dotenv

from google.oauth2 import id_token
from google.auth.transport import requests as google_requests
from bson import ObjectId
from flask.json.provider import DefaultJSONProvider
load_dotenv()

from flask_jwt_extended import (
    JWTManager, jwt_required, create_access_token,
    get_jwt_identity, get_jwt
)
from passlib.hash import bcrypt
import random

from db import db
from email_utils import send_registration_otp, send_forgot_password_otp, send_password_change_otp, send_processing_complete
from emotion_analyzer import analyze_emotions
from attention_curve import generate_attention_curve
from aws_utils import s3_storage, aws_ai

# ---------------------------------------------------------------------------
# Logging
# ---------------------------------------------------------------------------
logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s [%(levelname)s] %(name)s: %(message)s",
    handlers=[logging.StreamHandler(sys.stdout)],
)
logger = logging.getLogger("clipsense")

# ---------------------------------------------------------------------------
# App modules
# ---------------------------------------------------------------------------
from ai_engine import AIEngine
from video_processor import process_video

# ---------------------------------------------------------------------------
_engine_instance = AIEngine()

# Fallback local storage for when S3 is unavailable
LOCAL_STORAGE_DIR = os.getenv("LOCAL_STORAGE_DIR", "/tmp/clipsense_local")
UPLOAD_DIR = os.getenv("UPLOAD_DIR", "uploads")
CLIPS_DIR = os.getenv("CLIPS_DIR", "generated_clips")
os.makedirs(LOCAL_STORAGE_DIR, exist_ok=True)
os.makedirs(UPLOAD_DIR, exist_ok=True)
os.makedirs(CLIPS_DIR, exist_ok=True)

# ---------------------------------------------------------------------------
# Flask App
# ---------------------------------------------------------------------------
class CustomJSONProvider(DefaultJSONProvider):
    def default(self, o):
        from decimal import Decimal
        if isinstance(o, ObjectId):
            return str(o)
        if isinstance(o, datetime):
            return o.isoformat()
        if isinstance(o, Decimal):
            return float(o)
        return super().default(o)

app = Flask(__name__)
app.json = CustomJSONProvider(app)

CORS(app, resources={r"/api/*": {"origins": "*"}})

# JWT Configuration
app.config["JWT_SECRET_KEY"] = os.getenv("JWT_SECRET_KEY", "clipsense-super-secret-key")
app.config["JWT_TOKEN_LOCATION"] = ["headers", "query_string"]
app.config["JWT_QUERY_STRING_NAME"] = "token"
jwt = JWTManager(app)


# Simple in-memory metrics tracker for operations monitoring
_metrics = {
    "total_processed": 0,
    "total_failed": 0,
    "processing_times": [],
    "active_jobs": set(),
}
_metrics_lock = threading.Lock()

# Simple in-memory rate limiter for demo purposes
_rate_limits = {}
_rl_lock = threading.Lock()

# ========================  UTILS & DECORATORS  ========================

def role_required(required_role):
    """Decorator to restrict access to specific roles."""
    def decorator(fn):
        @jwt_required()
        def wrapper(*args, **kwargs):
            claims = get_jwt()
            if claims.get("role") != required_role:
                return jsonify({"message": f"{required_role.capitalize()} role required"}), 403
            return fn(*args, **kwargs)
        wrapper.__name__ = fn.__name__
        return wrapper
    return decorator

def rate_limit(limit=100, window=60):
    """Decorator for simple rate limiting (limit per window per IP)."""
    def decorator(fn):
        def wrapper(*args, **kwargs):
            ip = request.remote_addr
            now = time.time()
            with _rl_lock:
                if ip not in _rate_limits:
                    _rate_limits[ip] = []
                # Clean up old timestamps
                _rate_limits[ip] = [t for t in _rate_limits[ip] if t > now - window]
                if len(_rate_limits[ip]) >= limit:
                    return jsonify({"message": "Rate limit exceeded. Try again later."}), 429
                _rate_limits[ip].append(now)
            return fn(*args, **kwargs)
        wrapper.__name__ = fn.__name__
        return wrapper
    return decorator

def log_pipeline_failure(project_id, user_id, error_msg):
    """Persist pipeline failures for operations monitoring."""
    try:
        if db.db is not None:
             db.db.pipeline_logs.insert_one({
                "projectId": project_id,
                "userId": user_id,
                "error": error_msg,
                "timestamp": datetime.utcnow()
            })
        else:
            logger.warning("No MongoDB for logging pipeline failure. Project: %s", project_id)
    except Exception as e:
        logger.error("Failed to log pipeline failure: %s", e)


# ========================  HEALTH  ========================

@app.route("/api/health", methods=["GET"])
def health():
    engine_ok = _engine_instance is not None
    db_ok = db.is_connected()
    return jsonify({
        "status": "ok",
        "service": "clipsense-api",
        "engineReady": engine_ok,
        "dbReady": db_ok,
        "geminiKeySet": bool(os.getenv("GEMINI_API_KEY")),
    })


# ========================  AUTH  ========================

@app.route("/api/auth/register", methods=["POST"])
@rate_limit(limit=10)
def register():
    data = request.json
    email = data.get("email")
    password = data.get("password")
    role = data.get("role", "creator")

    if not email or not password:
        return jsonify({"message": "Email and password required"}), 400

    if db.get_user_by_email(email):
        return jsonify({"message": "User already exists"}), 400

    # Automatically assign admin role if email matches ADMIN_EMAIL
    if email == os.getenv("ADMIN_EMAIL", "admin@clipsense.ai"):
        role = "admin"
    elif role == "admin":
        role = "creator" # Don't allow others to register as admin

    username = data.get("username")
    if not username:
        username = email.split("@")[0]
        # Ensure default username is unique
        base_username = username
        counter = 1
        while db.get_user_by_username(username):
            username = f"{base_username}{counter}"
            counter += 1
    elif db.get_user_by_username(username):
        return jsonify({"message": "Username already taken"}), 400

    otp = str(random.randint(100000, 999999))
    logger.info("Generated OTP for %s: %s", email, otp)
    send_registration_otp(email, otp)

    user_data = {
        "email": email,
        "username": username,
        "password": bcrypt.hash(password),
        "isVerified": False,
        "otpCode": otp,
        "role": role,
        "createdAt": datetime.now().isoformat()
    }
    db.create_user(user_data)
    
    return jsonify({"message": "User registered. Check your email for OTP."}), 201

@app.route("/api/auth/verify-otp", methods=["POST"])
def verify_otp():
    data = request.json
    email = data.get("email")
    otp = data.get("otp")

    user = db.get_user_by_email(email)
    if not user or user.get("otpCode") != otp:
        return jsonify({"message": "Invalid OTP"}), 400

    db.verify_user(email)
    return jsonify({"message": "Account verified. You can now login."}), 200

@app.route("/api/auth/login", methods=["POST"])
@rate_limit(limit=20)
def login():
    data = request.json
    # Accept identifier (email or username)
    identifier = data.get("identifier") or data.get("email")
    password = data.get("password")

    if not identifier or not password:
        return jsonify({"message": "Email/Username and password required"}), 400

    user = db.get_user_by_identifier(identifier)
    if not user or not bcrypt.verify(password, user["password"]):
        return jsonify({"message": "Invalid credentials"}), 401

    if not user.get("isVerified"):
        return jsonify({"message": "Account not verified"}), 403

    # Include role in JWT
    access_token = create_access_token(
        identity=user["email"],
        additional_claims={"role": user.get("role", "creator")}
    )
    return jsonify({
        "token": access_token, 
        "user": {
            "email": user["email"],
            "username": user.get("username"),
            "role": user.get("role", "creator"),
            "region": os.getenv("AWS_REGION", "ap-south-1")
        }
    }), 200

@app.route("/api/auth/me", methods=["GET"])
@jwt_required()
def get_me():
    email = get_jwt_identity()
    user = db.get_user_by_email(email)
    if not user:
        return jsonify({"message": "User not found"}), 404
    return jsonify({
        "user": {
            "email": user["email"],
            "username": user.get("username", user["email"].split("@")[0])
        }
    }), 200

@app.route("/api/auth/update-profile", methods=["POST"])
@jwt_required()
def update_profile():
    email = get_jwt_identity()
    data = request.json
    new_username = data.get("username")

    if not new_username:
        return jsonify({"message": "Username is required"}), 400

    # Check if already taken
    existing = db.get_user_by_username(new_username)
    if existing and existing["email"] != email:
        return jsonify({"message": "Username already taken"}), 400

    db.update_user(email, {"username": new_username})
    return jsonify({"message": "Profile updated", "username": new_username}), 200

@app.route("/api/auth/request-password-change", methods=["POST"])
@jwt_required()
def request_password_change():
    email = get_jwt_identity()
    otp = str(random.randint(100000, 999999))
    logger.info("Password Change OTP for %s: %s", email, otp)
    db.update_user(email, {"passwordOtp": otp})
    send_password_change_otp(email, otp)
    return jsonify({"message": "OTP sent to console"}), 200

@app.route("/api/auth/confirm-password-change", methods=["POST"])
@jwt_required()
def confirm_password_change():
    email = get_jwt_identity()
    data = request.json
    otp = data.get("otp")
    new_password = data.get("password")

    if not otp or not new_password:
        return jsonify({"message": "OTP and new password required"}), 400

    user = db.get_user_by_email(email)
    if not user or user.get("passwordOtp") != otp:
        return jsonify({"message": "Invalid OTP"}), 400

    db.update_user(email, {
        "password": bcrypt.hash(new_password),
        "passwordOtp": None
    })
    return jsonify({"message": "Password updated successfully"}), 200

@app.route("/api/auth/stats", methods=["GET"])
@jwt_required()
def user_stats():
    email = get_jwt_identity()
    stats = db.get_user_stats(email)
    return jsonify(stats), 200

@app.route("/api/auth/delete-account", methods=["DELETE"])
@jwt_required()
def delete_account():
    email = get_jwt_identity()
    db.delete_user(email)
    logger.info("Account deleted: %s", email)
    return jsonify({"message": "Account deleted permanently"}), 200

@app.route("/api/auth/forgot-password", methods=["POST"])
def forgot_password():
    data = request.json
    email = data.get("email")
    if not email:
        return jsonify({"message": "Email is required"}), 400

    user = db.get_user_by_email(email)
    if not user:
        # Don't reveal whether the email exists
        return jsonify({"message": "If this email is registered, an OTP has been sent."}), 200

    otp = str(random.randint(100000, 999999))
    logger.info("FORGOT PASSWORD OTP for %s: %s", email, otp)
    db.update_user(email, {"resetOtp": otp})
    send_forgot_password_otp(email, otp)
    return jsonify({"message": "If this email is registered, an OTP has been sent."}), 200

@app.route("/api/auth/reset-password", methods=["POST"])
def reset_password():
    data = request.json
    email = data.get("email")
    otp = data.get("otp")
    new_password = data.get("password")

    if not email or not otp or not new_password:
        return jsonify({"message": "Email, OTP and new password are required"}), 400

    user = db.get_user_by_email(email)
    if not user or user.get("resetOtp") != otp:
        return jsonify({"message": "Invalid OTP"}), 400

    db.update_user(email, {
        "password": bcrypt.hash(new_password),
        "resetOtp": None
    })
    return jsonify({"message": "Password has been reset. You can now login."}), 200

@app.route("/api/auth/google", methods=["POST"])
def google_auth():
    data = request.json
    id_token_str = data.get("idToken")
    
    if not id_token_str:
        return jsonify({"message": "Token required"}), 400

    try:
        # Client ID for verification
        client_id = os.getenv("GOOGLE_CLIENT_ID")
        if not client_id:
            logger.warning("GOOGLE_CLIENT_ID not set in environment.")
            # We'll still try, but verification might fail or be insecure if not checked correctly
            # In a real app, this is mandatory.
        
        idinfo = id_token.verify_oauth2_token(id_token_str, google_requests.Request(), client_id)
        
        # ID token is valid. Extract user info.
        email = idinfo["email"]
        
        user = db.get_user_by_email(email)
        if not user:
            # Create a new user if they don't exist
            user_data = {
                "email": email,
                "isVerified": True, # Google emails are already verified
                "provider": "google",
                "createdAt": datetime.now()
            }
            db.create_user(user_data)
        
        access_token = create_access_token(identity=email)
        return jsonify({"token": access_token, "user": {"email": email}}), 200

    except ValueError:
        # Invalid token
        return jsonify({"message": "Invalid Google token"}), 401
    except Exception as e:
        logger.error("Google auth error: %s", e)
        return jsonify({"message": str(e)}), 500


# ========================  UPLOAD  ========================

ALLOWED_EXTENSIONS = {'mp4', 'mov', 'avi', 'mp3', 'wav', 'm4a', 'mkv', 'webm'}
MAX_FILE_SIZE = 5 * 1024 * 1024 * 1024  # 5GB

@app.route("/api/upload", methods=["POST"])
@jwt_required()
@rate_limit(limit=5, window=300) # Max 5 uploads per 5 mins
def upload_video():
    """Accept a video file via multipart form-data and create a project."""
    user_id = get_jwt_identity()

    if "file" not in request.files:
        return jsonify({"error": "No file part in request"}), 400

    file = request.files["file"]
    if file.filename == "":
        return jsonify({"error": "Empty filename"}), 400

    # Validate file extension
    ext = file.filename.rsplit('.', 1)[-1].lower() if '.' in file.filename else ''
    if ext not in ALLOWED_EXTENSIONS:
        return jsonify({"error": f"Unsupported format '.{ext}'. Allowed: {', '.join(sorted(ALLOWED_EXTENSIONS))}"}), 400

    project_id = str(uuid.uuid4())[:8]

    # Save to S3 via temp file
    s3_key = f"uploads/{user_id}/{project_id}/{file.filename}"
    temp_path = os.path.join("/tmp", f"{uuid.uuid4()}_{file.filename}")
    file.save(temp_path)
    
    s3_uri = s3_storage.upload_file(temp_path, s3_key)
    
    # If it's a local fallback, copy the file to the local storage dir so it persists for processing
    if s3_uri.startswith("local://"):
        filename = s3_uri.replace("local://", "")
        dest = os.path.join(LOCAL_STORAGE_DIR, filename)
        os.makedirs(os.path.dirname(dest), exist_ok=True)
        shutil.copy(temp_path, dest)
        
    os.remove(temp_path)

    if not s3_uri:
        return jsonify({"error": "Failed to upload to S3"}), 500

    logger.info("Uploaded video to S3: %s", s3_uri)

    # Derive title from filename
    title = os.path.splitext(file.filename)[0]

    # Get optional settings from form data
    max_duration = int(request.form.get("maxDuration", 15))
    num_clips = int(request.form.get("numClips", 3))
    use_subs = request.form.get("useSubs", "true").lower() == "true"

    project = {
        "projectId": project_id,
        "userId": user_id,
        "title": title,
        "filename": file.filename,
        "s3Uri": s3_uri,
        "s3Key": s3_key,
        "createdAt": datetime.utcnow().isoformat() + "Z",
        "duration": None,
        "status": "uploaded",
        "maxDuration": max_duration,
        "numClips": num_clips,
        "useSubs": use_subs,
        "clips": [],
        "clipCount": 0,
        "avgEngagement": 0,
        "transcription": None,
        "currentStep": "Waiting...",
        "progress": 0,
        "analysis": None,
        "emotionData": None,
        "attentionCurve": None,
        "error": None,
    }

    db.create_project(project)

    # Convert ObjectId to string for JSON serialization
    if "_id" in project:
        project["_id"] = str(project["_id"])

    logger.info("Created project %s for user %s", project_id, user_id)
    return jsonify({"id": project_id, "project": project}), 201


# ========================  PROJECTS LIST  ========================

@app.route("/api/projects", methods=["GET"])
@jwt_required()
def list_projects_route():
    """Return all projects for the logged-in user."""
    user_id = get_jwt_identity()
    claims = get_jwt()
    if claims.get("role") == "admin":
        items = db.list_all_projects_admin()
    else:
        items = db.list_projects(user_id)
    # Convert BSON types or extra fields if needed safely
    for item in items:
        if "_id" in item:
            item["_id"] = str(item["_id"])
    return jsonify(items)


# ========================  PROJECT DETAIL  ========================

@app.route("/api/projects/<project_id>", methods=["GET"])
@jwt_required()
def get_project_route(project_id):
    """Return a single project by ID (must belong to user, unless admin)."""
    user_id = get_jwt_identity()
    claims = get_jwt()
    if claims.get("role") == "admin":
        project = db.get_project(project_id)
    else:
        project = db.get_project(project_id, user_id)
        
    if not project:
        return jsonify({"error": "Project not found"}), 404
    
    if "_id" in project:
        project["_id"] = str(project["_id"])
    return jsonify(project)


@app.route("/api/projects/<project_id>/clips", methods=["GET"])
@jwt_required()
def get_project_clips(project_id):
    """Return all clips for a specific project."""
    user_id = get_jwt_identity()
    project = db.get_project(project_id, user_id)
    if not project:
        return jsonify({"error": "Project not found"}), 404
    
    clips = project.get("clips", [])
    return jsonify(clips)


# ========================  PROCESS (AI)  ========================

def _run_processing(project_id: str):
    """Background worker that runs transcription → analysis → clip rendering."""
    logger.info("[PROCESS] Starting processing for project: %s", project_id)
    start_time = time.time()

    project = db.get_project(project_id)
    if not project:
        logger.error("[PROCESS] Project %s not found", project_id)
        return

    s3_uri = project.get("s3Uri")
    max_duration = project.get("maxDuration", 15)
    num_clips = project.get("numClips", 3)

    try:
        # STEP 1: Transcribe via AWS
        db.update_project(project_id, {"status": "processing", "currentStep": "Transcribing...", "progress": 10})
        transcribe_result = _engine_instance.transcribe_video(s3_uri)
        transcript_segments = transcribe_result.get("segments", [])
        
        db.update_project(project_id, {"transcription": transcript_segments, "progress": 30})

        # STEP 2: Audio Emotion Analysis (simplified for now, using transcript + spectral placeholder)
        db.update_project(project_id, {"currentStep": "Analyzing Audio Emotions...", "progress": 40})
        # Note: In a full Lambda flow, we'd extract audio to a temp file here
        emotion_data = analyze_emotions(transcript_segments, engine=_engine_instance)
        db.update_project(project_id, {"emotionData": emotion_data, "progress": 50})

        # STEP 2.5: Generate Attention Curve
        logger.info("[PROCESS] Generating attention curve...")
        # Get video duration from segments if possible (Ensure float)
        video_duration = float(transcript_segments[-1]["end"]) if transcript_segments else 0.0
        attention_curve = generate_attention_curve(emotion_data, video_duration=video_duration)
        db.update_project(project_id, {"attentionCurve": attention_curve, "progress": 55})

        # STEP 2.6: Visual Analysis (Rekognition)
        db.update_project(project_id, {"currentStep": "Analyzing Visuals (Rekognition)...", "progress": 58})
        visual_data = None
        if str(s3_uri).startswith("s3://"):
             visual_data = _engine_instance.analyze_visuals(s3_uri)
             
        # STEP 3: Bedrock Viral Analysis
        db.update_project(project_id, {"currentStep": "AI Selection (Bedrock)...", "progress": 60})
        clips_metadata = _engine_instance.analyze_transcription_with_timestamps(
            transcript_segments, 
            visual_data=visual_data,
            num_clips=num_clips,
            max_duration=max_duration
        )
        
        # STEP 3.5: Add emotional analysis detail for each clip
        for clip in clips_metadata:
            c_start = clip.get("start_time", 0)
            c_end = clip.get("end_time", 0)
            
            # Find emotions in this range
            clip_emotions = [e for e in emotion_data if e["timestamp"] >= c_start and e["timestamp"] <= c_end]
            if clip_emotions:
                avg_intensity = sum(e.get("intensity", 0) for e in clip_emotions) / len(clip_emotions)
                # Find primary emotion
                emotions = ["joy", "sadness", "anger", "surprise", "neutral"]
                emotion_sums = {em: sum(e.get(em, 0) for e in clip_emotions) / len(clip_emotions) for em in emotions}
                primary = max(emotion_sums, key=emotion_sums.get)
                
                clip["emotional_analysis"] = {
                    "intensity_score": round(avg_intensity * 100, 1),
                    "primary_emotion": primary,
                    "insight": f"This clip has a {primary} tone with {round(avg_intensity * 100)}% engagement intensity."
                }
            else:
                clip["emotional_analysis"] = {"insight": "Emotional data not available for this segment."}
        
        # STEP 4: Rendering (On AWS, we'd trigger a specialized MediaConvert or Batch job, 
        # but for this Refactor we'll keep the local processor if possible or note the transition)
        # STEP 4: Rendering
        db.update_project(project_id, {"currentStep": "Rendering Clips...", "progress": 80})
        
        # Download video to a temporary file for processing
        temp_source = tempfile.NamedTemporaryFile(delete=False, suffix=".mp4")
        local_video_path = temp_source.name
        temp_source.close()
        
        if str(s3_uri).startswith("local://"):
            # S3 was down/skipped during upload, file is already in LOCAL_STORAGE_DIR
            filename = s3_uri.replace("local://", "")
            source_path = os.path.join(LOCAL_STORAGE_DIR, filename)
            if os.path.exists(source_path):
                shutil.copy(source_path, local_video_path)
            else:
                raise Exception(f"Local source file not found: {source_path}")
        else:
            logger.info("[PROCESS] Downloading source from S3 for rendering: %s", s3_uri)
            s3 = s3_storage.s3_client
            bucket = project['s3Uri'].split('/')[2]
            key = "/".join(project['s3Uri'].split('/')[3:])
            s3.download_file(bucket, key, local_video_path)

        project_clips_dir = os.path.join("/tmp", f"clips_{project_id}")
        os.makedirs(project_clips_dir, exist_ok=True)

        generated_paths = process_video(
            local_video_path,
            clips_metadata,
            transcript_segments=transcript_segments,
            output_dir=project_clips_dir,
            use_subs=project.get("useSubs", True),
            max_clip_duration=max_duration,
            crop_mode="Letterbox",
        )

        # STEP 5: Upload clips to S3
        clips_list = []
        for idx, local_clip_path in enumerate(generated_paths):
            clip_filename = os.path.basename(local_clip_path)
            s3_clip_key = f"clips/{project['userId']}/{project_id}/{clip_filename}"
            s3_clip_uri = s3_storage.upload_file(local_clip_path, s3_clip_key)
            
            meta = clips_metadata[idx] if idx < len(clips_metadata) else {}
            clip_id = f"{project_id}_clip_{idx}"
            
            clips_list.append({
                "id": clip_id,
                "index": idx,
                "filename": clip_filename,
                "s3Key": s3_clip_key,
                "s3Uri": s3_clip_uri,
                "startTime": meta.get("start_time", 0),
                "endTime": meta.get("end_time", 0),
                "viralScore": meta.get("viral_score", 0),
                "hookTitle": meta.get("hook_title", ""),
                "caption": meta.get("caption", ""),
                "summary": meta.get("summary", ""),
                "hashtags": meta.get("hashtags", ""),
                "transcript": "" # Could extract from segments
            })

        # Cleanup /tmp (Robust for Windows)
        try:
            time.sleep(1) # Give OS a breath to release handles
            if os.path.exists(local_video_path):
                os.remove(local_video_path)
            if os.path.exists(project_clips_dir):
                shutil.rmtree(project_clips_dir)
            logger.info("[PROCESS] Cleanup successful for %s", project_id)
        except Exception as cleanup_err:
            logger.warning("[PROCESS] Cleanup warning for %s: %s", project_id, cleanup_err)

        avg_engagement = round(sum(c["viralScore"] for c in clips_list) / len(clips_list), 1) if clips_list else 0

        db.update_project(project_id, {
            "clips": clips_list,
            "clipCount": len(clips_list),
            "avgEngagement": avg_engagement,
            "status": "done",
            "currentStep": "Completed",
            "progress": 100
        })

        logger.info("[PROCESS] ✅ Project %s DONE — %d clips processed and uploaded", project_id, len(clips_list))
        
        # Send email
        user_email = project.get("userId")
        if user_email: send_processing_complete(user_email, project.get("title"), len(clips_list), avg_engagement)

    except Exception as e:
        logger.error("[PROCESS] ❌ Project %s FAILED: %s", project_id, e, exc_info=True)
        db.update_project(project_id, {"status": "error", "error": str(e)})

@app.route("/api/projects/<project_id>/process", methods=["POST"])
@jwt_required()
def process_project_route(project_id):
    """Trigger the background processing thread for a project."""
    user_id = get_jwt_identity()
    project = db.get_project(project_id, user_id)
    if not project:
        return jsonify({"error": "Project not found"}), 404

    if project.get("status") in ["processing", "done"]:
        return jsonify({"message": f"Project is already {project.get('status')}", "status": project.get("status")}), 200

    # Start the worker thread
    thread = threading.Thread(target=_run_processing, args=(project_id,))
    thread.daemon = True
    thread.start()

    return jsonify({"message": "Processing started", "status": "processing"}), 202

@app.route("/api/projects/<project_id>/status", methods=["GET"])
@jwt_required()
def get_project_status_route(project_id):
    """Return the current status and progress of a project."""
    user_id = get_jwt_identity()
    project = db.get_project(project_id, user_id)
    if not project:
        return jsonify({"error": "Project not found"}), 404
        
    return jsonify({
        "status": project.get("status"),
        "currentStep": project.get("currentStep"),
        "progress": project.get("progress"),
        "error": project.get("error")
    })

@app.route("/api/clips/<clip_id>/download", methods=["GET"])
@jwt_required()
def download_clip(clip_id):
    """Generate a pre-signed URL for clip download."""
    user_id = get_jwt_identity()
    project_id = clip_id.rsplit("_clip_", 1)[0]
    project = db.get_project(project_id, user_id)

    if not project: return jsonify({"error": "Not found"}), 404

    clip = next((c for c in project.get("clips", []) if c["id"] == clip_id), None)
    if not clip: return jsonify({"error": "Clip not found"}), 404

    url = s3_storage.get_presigned_url(clip['s3Key'])
    from flask import redirect
    return redirect(url)

@app.route("/api/projects/<project_id>/video", methods=["GET"])
@jwt_required()
def stream_project_video(project_id):
    """Generate a pre-signed URL for original video streaming."""
    user_id = get_jwt_identity()
    project = db.get_project(project_id, user_id)
    if not project: return jsonify({"error": "Not found"}), 404

    url = s3_storage.get_presigned_url(project['s3Key'])
    from flask import redirect
    return redirect(url)

@app.route("/api/projects/download_local/<path:filename>", methods=["GET"])
@jwt_required()
def download_local_file(filename):
    """Fallback route to serve files directly from the server if S3 is unavailable."""
    # Note: In production, you'd want stricter security checks here.
    file_path = os.path.join(LOCAL_STORAGE_DIR, filename)
    if not os.path.exists(file_path):
        return jsonify({"error": "File not found locally"}), 404
    return send_file(file_path)


# ========================  RESET stuck project  ========================

@app.route("/api/projects/<project_id>/reset", methods=["POST"])
@jwt_required()
def reset_project(project_id):
    """Reset a stuck project back to 'uploaded' status."""
    user_id = get_jwt_identity()
    project = db.get_project(project_id, user_id)
    if not project:
        return jsonify({"error": "Project not found"}), 404

    db.update_project(project_id, {
        "status": "uploaded",
        "error": None,
        "transcription": None,
        "analysis": None,
        "clips": [],
        "clipCount": 0,
        "avgEngagement": 0
    })

    logger.info("Reset project %s to 'uploaded' status", project_id)
    return jsonify({"message": "Project reset", "status": "uploaded"})


# ========================  DELETE PROJECT  ========================

@app.route("/api/projects/<project_id>", methods=["DELETE"])
@jwt_required()
def delete_project_route(project_id):
    """Delete a project and all its associated files."""
    user_id = get_jwt_identity()
    project = db.get_project(project_id, user_id)
    if not project:
        return jsonify({"error": "Project not found"}), 404

    # 1. Delete project directory (contains local fallback video)
    project_dir = os.path.join(UPLOAD_DIR, project_id)
    if os.path.exists(project_dir):
        try:
            shutil.rmtree(project_dir)
            logger.info("Deleted project directory: %s", project_dir)
        except Exception as e:
            logger.error("Failed to delete project directory %s: %s", project_dir, e)

    # 2. Delete generated clips directory
    clips_project_dir = os.path.join(CLIPS_DIR, project_id)
    if os.path.exists(clips_project_dir):
        try:
            shutil.rmtree(clips_project_dir)
            logger.info("Deleted clips directory: %s", clips_project_dir)
        except Exception as e:
            logger.error("Failed to delete clips directory %s: %s", clips_project_dir, e)

    # 3. Clean up S3 resources
    try:
        # Delete original upload prefix
        s3_storage.delete_prefix(f"uploads/{user_id}/{project_id}/")
        # Delete generated clips prefix
        s3_storage.delete_prefix(f"clips/{user_id}/{project_id}/")
    except Exception as e:
        logger.error("S3 cleanup failed during deletion for %s: %s", project_id, e)

    # 4. Remove from DB
    db.delete_project(project_id, user_id)

    logger.info("Deleted project %s from store", project_id)
    return jsonify({"message": "Project deleted", "id": project_id})


# ========================  TRANSCRIPT DOWNLOAD  ========================

@app.route("/api/projects/<project_id>/transcript", methods=["GET"])
@jwt_required()
def download_transcript(project_id):
    """Generate and serve a text transcript file."""
    user_id = get_jwt_identity()
    project = db.get_project(project_id, user_id)
    if not project:
        return jsonify({"error": "Project not found"}), 404

    transcription = project.get("transcription")
    if not transcription:
        return jsonify({"error": "No transcription found for this project"}), 404

    # Generate transcript text
    lines = []
    for seg in transcription:
        start = seg.get('start', 0)
        end = seg.get('end', 0)
        text = seg.get('text', '').strip()
        
        m, s = divmod(int(start), 60)
        timestamp = f"[{m:02d}:{s:02d}]"
        lines.append(f"{timestamp} {text}")

    content = "\n".join(lines)
    
    # Save to a temporary file or serve as memory
    from io import BytesIO
    buffer = BytesIO()
    buffer.write(content.encode('utf-8'))
    buffer.seek(0)

    filename = f"transcript_{project['title']}.txt"
    return send_file(
        buffer,
        as_attachment=True,
        download_name=filename,
        mimetype="text/plain"
    )


# ========================  EMOTION DATA  ========================

@app.route("/api/projects/<project_id>/emotions", methods=["GET"])
@jwt_required()
def get_emotions(project_id):
    """Return emotion timeline data for a project."""
    user_id = get_jwt_identity()
    project = db.get_project(project_id, user_id)
    if not project:
        return jsonify({"error": "Project not found"}), 404

    emotion_data = project.get("emotionData", [])
    return jsonify(emotion_data)


# ========================  ATTENTION CURVE  ========================

@app.route("/api/projects/<project_id>/attention-curve", methods=["GET"])
@jwt_required()
def get_attention_curve(project_id):
    """Return attention curve data for a project."""
    user_id = get_jwt_identity()
    project = db.get_project(project_id, user_id)
    if not project:
        return jsonify({"error": "Project not found"}), 404

    curve_data = project.get("attentionCurve", {})
    return jsonify(curve_data)


# ========================  CLIP DETAIL  ========================

@app.route("/api/clips/<clip_id>/detail", methods=["GET"])
@jwt_required()
def get_clip_detail(clip_id):
    """Return full detail for a single clip including hook title and caption."""
    user_id = get_jwt_identity()
    parts = clip_id.rsplit("_clip_", 1)
    if len(parts) != 2:
        return jsonify({"error": "Invalid clip ID"}), 400

    project_id = parts[0]
    project = db.get_project(project_id, user_id)
    if not project:
        return jsonify({"error": "Project not found"}), 404

    clip = next((c for c in project.get("clips", []) if c["id"] == clip_id), None)
    if not clip:
        return jsonify({"error": "Clip not found"}), 404

    clip["downloadUrl"] = f"/api/clips/{clip['id']}/download"
    return jsonify(clip)


# ========================  METADATA EXPORT  ========================

@app.route("/api/projects/<project_id>/export", methods=["GET"])
@jwt_required()
def export_metadata(project_id):
    """Export all clips metadata as a downloadable JSON file."""
    user_id = get_jwt_identity()
    project = db.get_project(project_id, user_id)
    if not project:
        return jsonify({"error": "Project not found"}), 404

    export_data = {
        "projectId": project_id,
        "title": project.get("title", ""),
        "createdAt": project.get("createdAt", ""),
        "duration": project.get("duration"),
        "clipCount": project.get("clipCount", 0),
        "avgEngagement": project.get("avgEngagement", 0),
        "clips": []
    }

    for clip in project.get("clips", []):
        export_data["clips"].append({
            "id": clip.get("id"),
            "startTime": clip.get("startTime", 0),
            "endTime": clip.get("endTime", 0),
            "viralScore": clip.get("viralScore", 0),
            "hookTitle": clip.get("hookTitle", ""),
            "caption": clip.get("caption", ""),
            "summary": clip.get("summary", ""),
            "hashtags": clip.get("hashtags", ""),
            "emotionalAnalysis": clip.get("emotional_analysis", {})
        })

    buffer = BytesIO()
    buffer.write(json.dumps(export_data, indent=2).encode("utf-8"))
    buffer.seek(0)

    filename = f"clipsense_{project.get('title', 'export')}_clips.json"
    return send_file(buffer, as_attachment=True, download_name=filename, mimetype="application/json")


# ========================  BATCH ZIP DOWNLOAD  ========================

@app.route("/api/projects/<project_id>/download-all", methods=["GET"])
@jwt_required()
def download_all_clips(project_id):
    """Download all clips as a ZIP archive."""
    user_id = get_jwt_identity()
    project = db.get_project(project_id, user_id)
    if not project:
        return jsonify({"error": "Project not found"}), 404

    clips = project.get("clips", [])
    if not clips:
        return jsonify({"error": "No clips available"}), 404

    buffer = BytesIO()
    with zipfile.ZipFile(buffer, "w", zipfile.ZIP_DEFLATED) as zf:
        for clip in clips:
            clip_path = clip.get("path", "")
            if clip_path and os.path.exists(clip_path):
                zf.write(clip_path, clip.get("filename", os.path.basename(clip_path)))
    
    buffer.seek(0)
    filename = f"clipsense_{project.get('title', 'clips')}_all.zip"
    return send_file(buffer, as_attachment=True, download_name=filename, mimetype="application/zip")


# ========================  ADMIN METRICS  ========================

@app.route("/api/admin/metrics", methods=["GET"])
@role_required("admin")
def admin_metrics():
    """Return system health and pipeline performance metrics."""
    with _metrics_lock:
        total = _metrics["total_processed"] + _metrics["total_failed"]
        error_rate = (_metrics["total_failed"] / total * 100) if total > 0 else 0
        avg_time = (
            sum(_metrics["processing_times"]) / len(_metrics["processing_times"])
            if _metrics["processing_times"] else 0
        )

    # Count active/queued jobs from DB
    all_projects = db.projects.find({"status": {"$in": ["processing", "uploaded"]}})
    project_list = list(all_projects)
    processing_count = sum(1 for p in project_list if p.get("status") == "processing")
    queued_count = sum(1 for p in project_list if p.get("status") == "uploaded")

    return jsonify({
        "engineReady": _engine_instance is not None,
        "dbReady": db.is_connected(),
        "activeJobs": processing_count,
        "queueLength": queued_count,
        "totalProcessed": _metrics["total_processed"],
        "totalFailed": _metrics["total_failed"],
        "errorRate": round(error_rate, 1),
        "avgProcessingTimeSec": round(avg_time, 1),
    })

@app.route("/api/admin/users", methods=["GET"])
@role_required("admin")
def admin_list_users():
    """Return all creators with their performance stats."""
    creators = db.list_all_users_with_stats()
    return jsonify(creators)

@app.route("/api/admin/all-projects", methods=["GET"])
@role_required("admin")
def admin_list_all_projects():
    """Global feed of all projects on the platform."""
    projects = db.list_all_projects_admin()
    for p in projects:
        p["_id"] = str(p["_id"])
    return jsonify(projects)


# ========================  MAIN  ========================

if __name__ == "__main__":
    port = int(os.getenv("FLASK_PORT", 5000))
    logger.info("ClipSense API starting on http://localhost:%d", port)
    # IMPORTANT: use_reloader=False prevents the debug reloader from
    # spawning a second process that kills background threads.
    app.run(host="0.0.0.0", port=port, debug=True, use_reloader=False)

