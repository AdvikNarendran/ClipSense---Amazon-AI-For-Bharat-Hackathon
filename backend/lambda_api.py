"""
Lambda API for ClipSense - Lightweight API endpoints only.
This module handles authentication, upload, project management, and status endpoints.
Video processing is delegated to EC2 worker via SQS.
"""

import os
import sys
import uuid
import json
import logging
import time
import boto3
from datetime import datetime

from flask import Flask, request, jsonify, redirect
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
from email_utils import send_registration_otp, send_forgot_password_otp, send_password_change_otp
from aws_utils import s3_storage

# ---------------------------------------------------------------------------
# Logging
# ---------------------------------------------------------------------------
logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s [%(levelname)s] %(name)s: %(message)s",
    handlers=[logging.StreamHandler(sys.stdout)],
)
logger = logging.getLogger("clipsense-lambda")

# ---------------------------------------------------------------------------
# SQS Client for sending processing jobs
# ---------------------------------------------------------------------------
sqs_client = boto3.client('sqs', region_name=os.getenv('AWS_REGION', 'ap-south-1'))
SQS_QUEUE_URL = os.getenv('SQS_QUEUE_URL')

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

# Simple in-memory rate limiter
_rate_limits = {}
_rl_lock = None

try:
    import threading
    _rl_lock = threading.Lock()
except:
    # Lambda may not have threading, use simple dict
    pass

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
    """Decorator for simple rate limiting."""
    def decorator(fn):
        def wrapper(*args, **kwargs):
            ip = request.remote_addr
            now = time.time()
            if _rl_lock:
                with _rl_lock:
                    if ip not in _rate_limits:
                        _rate_limits[ip] = []
                    _rate_limits[ip] = [t for t in _rate_limits[ip] if t > now - window]
                    if len(_rate_limits[ip]) >= limit:
                        return jsonify({"message": "Rate limit exceeded. Try again later."}), 429
                    _rate_limits[ip].append(now)
            else:
                # Fallback without lock
                if ip not in _rate_limits:
                    _rate_limits[ip] = []
                _rate_limits[ip] = [t for t in _rate_limits[ip] if t > now - window]
                if len(_rate_limits[ip]) >= limit:
                    return jsonify({"message": "Rate limit exceeded. Try again later."}), 429
                _rate_limits[ip].append(now)
            return fn(*args, **kwargs)
        wrapper.__name__ = fn.__name__
        return wrapper
    return decorator

# ========================  HEALTH  ========================

@app.route("/api/health", methods=["GET"])
def health():
    """Health check endpoint."""
    db_ok = db.is_connected()
    s3_ok = s3_storage is not None
    return jsonify({
        "status": "healthy" if db_ok and s3_ok else "degraded",
        "service": "clipsense-lambda-api",
        "dbReady": db_ok,
        "s3Ready": s3_ok,
        "sqsConfigured": bool(SQS_QUEUE_URL),
    })

# ========================  AUTH  ========================

@app.route("/api/auth/register", methods=["POST"])
@rate_limit(limit=10)
def register():
    """Register a new user."""
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
        role = "creator"

    username = data.get("username")
    if not username:
        username = email.split("@")[0]
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
    """Verify OTP for user registration."""
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
    """User login endpoint."""
    data = request.json
    identifier = data.get("identifier") or data.get("email")
    password = data.get("password")

    if not identifier or not password:
        return jsonify({"message": "Email/Username and password required"}), 400

    user = db.get_user_by_identifier(identifier)
    if not user or not bcrypt.verify(password, user["password"]):
        return jsonify({"message": "Invalid credentials"}), 401

    if not user.get("isVerified"):
        return jsonify({"message": "Account not verified"}), 403

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
    """Get current user information."""
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
    """Update user profile."""
    email = get_jwt_identity()
    data = request.json
    new_username = data.get("username")

    if not new_username:
        return jsonify({"message": "Username is required"}), 400

    existing = db.get_user_by_username(new_username)
    if existing and existing["email"] != email:
        return jsonify({"message": "Username already taken"}), 400

    db.update_user(email, {"username": new_username})
    return jsonify({"message": "Profile updated", "username": new_username}), 200

@app.route("/api/auth/request-password-change", methods=["POST"])
@jwt_required()
def request_password_change():
    """Request password change OTP."""
    email = get_jwt_identity()
    otp = str(random.randint(100000, 999999))
    logger.info("Password Change OTP for %s: %s", email, otp)
    db.update_user(email, {"passwordOtp": otp})
    send_password_change_otp(email, otp)
    return jsonify({"message": "OTP sent to console"}), 200

@app.route("/api/auth/confirm-password-change", methods=["POST"])
@jwt_required()
def confirm_password_change():
    """Confirm password change with OTP."""
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
    """Get user statistics."""
    email = get_jwt_identity()
    stats = db.get_user_stats(email)
    return jsonify(stats), 200

@app.route("/api/auth/delete-account", methods=["DELETE"])
@jwt_required()
def delete_account():
    """Delete user account."""
    email = get_jwt_identity()
    db.delete_user(email)
    logger.info("Account deleted: %s", email)
    return jsonify({"message": "Account deleted permanently"}), 200

@app.route("/api/auth/forgot-password", methods=["POST"])
def forgot_password():
    """Request password reset OTP."""
    data = request.json
    email = data.get("email")
    if not email:
        return jsonify({"message": "Email is required"}), 400

    user = db.get_user_by_email(email)
    if not user:
        return jsonify({"message": "If this email is registered, an OTP has been sent."}), 200

    otp = str(random.randint(100000, 999999))
    logger.info("FORGOT PASSWORD OTP for %s: %s", email, otp)
    db.update_user(email, {"resetOtp": otp})
    send_forgot_password_otp(email, otp)
    return jsonify({"message": "If this email is registered, an OTP has been sent."}), 200

@app.route("/api/auth/reset-password", methods=["POST"])
def reset_password():
    """Reset password with OTP."""
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
    """Google OAuth authentication."""
    data = request.json
    id_token_str = data.get("idToken")
    
    if not id_token_str:
        return jsonify({"message": "Token required"}), 400

    try:
        client_id = os.getenv("GOOGLE_CLIENT_ID")
        if not client_id:
            logger.warning("GOOGLE_CLIENT_ID not set in environment.")
        
        idinfo = id_token.verify_oauth2_token(id_token_str, google_requests.Request(), client_id)
        email = idinfo["email"]
        
        user = db.get_user_by_email(email)
        if not user:
            user_data = {
                "email": email,
                "isVerified": True,
                "provider": "google",
                "createdAt": datetime.now()
            }
            db.create_user(user_data)
        
        access_token = create_access_token(identity=email)
        return jsonify({"token": access_token, "user": {"email": email}}), 200

    except ValueError:
        return jsonify({"message": "Invalid Google token"}), 401
    except Exception as e:
        logger.error("Google auth error: %s", e)
        return jsonify({"message": str(e)}), 500

# ========================  UPLOAD  ========================

ALLOWED_EXTENSIONS = {'mp4', 'mov', 'avi', 'mp3', 'wav', 'm4a', 'mkv', 'webm'}

@app.route("/api/upload", methods=["POST"])
@jwt_required()
@rate_limit(limit=5, window=300)
def upload_video():
    """Accept video upload, save to S3, and send processing job to SQS."""
    user_id = get_jwt_identity()

    if "file" not in request.files:
        return jsonify({"error": "No file part in request"}), 400

    file = request.files["file"]
    if file.filename == "":
        return jsonify({"error": "Empty filename"}), 400

    ext = file.filename.rsplit('.', 1)[-1].lower() if '.' in file.filename else ''
    if ext not in ALLOWED_EXTENSIONS:
        return jsonify({"error": f"Unsupported format '.{ext}'. Allowed: {', '.join(sorted(ALLOWED_EXTENSIONS))}"}), 400

    project_id = str(uuid.uuid4())[:8]

    # Save to S3
    s3_key = f"uploads/{user_id}/{project_id}/{file.filename}"
    temp_path = os.path.join("/tmp", f"{uuid.uuid4()}_{file.filename}")
    file.save(temp_path)
    
    s3_uri = s3_storage.upload_file(temp_path, s3_key)
    os.remove(temp_path)

    if not s3_uri:
        return jsonify({"error": "Failed to upload to S3"}), 500

    logger.info("Uploaded video to S3: %s", s3_uri)

    title = os.path.splitext(file.filename)[0]
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

    # Send processing job to SQS
    if SQS_QUEUE_URL:
        try:
            message_body = {
                "projectId": project_id,
                "userId": user_id,
                "s3Uri": s3_uri,
                "s3Key": s3_key,
                "settings": {
                    "maxDuration": max_duration,
                    "numClips": num_clips,
                    "useSubs": use_subs
                },
                "timestamp": datetime.utcnow().isoformat() + "Z"
            }
            
            sqs_client.send_message(
                QueueUrl=SQS_QUEUE_URL,
                MessageBody=json.dumps(message_body)
            )
            logger.info("Sent processing job to SQS for project %s", project_id)
        except Exception as e:
            logger.error("Failed to send SQS message: %s", e)
            # Don't fail the upload, just log the error

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
    
    for item in items:
        if "_id" in item:
            item["_id"] = str(item["_id"])
    return jsonify(items)

# ========================  PROJECT DETAIL  ========================

@app.route("/api/projects/<project_id>", methods=["GET"])
@jwt_required()
def get_project_route(project_id):
    """Return a single project by ID."""
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

# ========================  PROJECT STATUS  ========================

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

# ========================  CLIP DOWNLOAD  ========================

@app.route("/api/clips/<clip_id>/download", methods=["GET"])
@jwt_required()
def download_clip(clip_id):
    """Generate a pre-signed URL for clip download."""
    user_id = get_jwt_identity()
    project_id = clip_id.rsplit("_clip_", 1)[0]
    project = db.get_project(project_id, user_id)

    if not project:
        return jsonify({"error": "Not found"}), 404

    clip = next((c for c in project.get("clips", []) if c["id"] == clip_id), None)
    if not clip:
        return jsonify({"error": "Clip not found"}), 404

    url = s3_storage.get_presigned_url(clip['s3Key'])
    return redirect(url)

@app.route("/api/projects/<project_id>/video", methods=["GET"])
@jwt_required()
def stream_project_video(project_id):
    """Generate a pre-signed URL for original video streaming."""
    user_id = get_jwt_identity()
    project = db.get_project(project_id, user_id)
    if not project:
        return jsonify({"error": "Not found"}), 404

    url = s3_storage.get_presigned_url(project['s3Key'])
    return redirect(url)

# ========================  DELETE PROJECT  ========================

@app.route("/api/projects/<project_id>", methods=["DELETE"])
@jwt_required()
def delete_project_route(project_id):
    """Delete a project and all its associated files."""
    user_id = get_jwt_identity()
    project = db.get_project(project_id, user_id)
    if not project:
        return jsonify({"error": "Project not found"}), 404

    # Clean up S3 resources
    try:
        s3_storage.delete_prefix(f"uploads/{user_id}/{project_id}/")
        s3_storage.delete_prefix(f"clips/{user_id}/{project_id}/")
    except Exception as e:
        logger.error("S3 cleanup failed during deletion for %s: %s", project_id, e)

    # Remove from DB
    db.delete_project(project_id, user_id)

    logger.info("Deleted project %s from store", project_id)
    return jsonify({"message": "Project deleted", "id": project_id})

# ========================  ADMIN ENDPOINTS  ========================

@app.route("/api/admin/metrics", methods=["GET"])
@role_required("admin")
def admin_metrics():
    """Get admin metrics."""
    metrics = db.get_admin_metrics()
    return jsonify(metrics), 200

@app.route("/api/admin/users", methods=["GET"])
@role_required("admin")
def admin_list_users():
    """List all users (admin only)."""
    users = db.list_all_users()
    return jsonify(users), 200

@app.route("/api/admin/projects", methods=["GET"])
@role_required("admin")
def admin_list_all_projects():
    """List all projects (admin only)."""
    projects = db.list_all_projects_admin()
    return jsonify(projects), 200

# ========================  MAIN  ========================

if __name__ == "__main__":
    port = int(os.getenv("PORT", 5000))
    app.run(host="0.0.0.0", port=port, debug=False)
