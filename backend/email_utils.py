"""
Email utility for ClipSense.
Uses Gmail SMTP to send OTP codes and notifications.
"""

import os
import smtplib
import logging
from email.mime.text import MIMEText
from email.mime.multipart import MIMEMultipart
from dotenv import load_dotenv

load_dotenv()

logger = logging.getLogger("clipsense.email")

SMTP_HOST = "smtp.gmail.com"
SMTP_PORT = 587
SENDER_EMAIL = os.getenv("SENDER_EMAIL", "")
SENDER_PASSWORD = os.getenv("SENDER_PASSWORD", "")

def _send_email(to_email: str, subject: str, html_body: str):
    """Send an email via Gmail SMTP."""
    if not SENDER_EMAIL or not SENDER_PASSWORD:
        logger.warning("Email credentials not configured. Skipping email to %s", to_email)
        return False

    try:
        msg = MIMEMultipart("alternative")
        msg["From"] = f"ClipSense <{SENDER_EMAIL}>"
        msg["To"] = to_email
        msg["Subject"] = subject
        msg.attach(MIMEText(html_body, "html"))

        with smtplib.SMTP(SMTP_HOST, SMTP_PORT) as server:
            server.starttls()
            server.login(SENDER_EMAIL, SENDER_PASSWORD)
            server.sendmail(SENDER_EMAIL, to_email, msg.as_string())

        logger.info("Email sent to %s: %s", to_email, subject)
        return True
    except Exception as e:
        logger.error("Failed to send email to %s: %s", to_email, e)
        return False


def send_registration_otp(to_email: str, otp: str):
    """Send registration OTP email."""
    html = f"""
    <div style="font-family: 'Segoe UI', sans-serif; max-width: 480px; margin: auto; padding: 32px; background: #f8f9fa; border-radius: 16px;">
        <div style="text-align: center; margin-bottom: 24px;">
            <span style="font-size: 28px; font-weight: 800; letter-spacing: -1px;">
                <span style="color: #A89E53;">Clip</span><span style="color: #B7561F;">Sense</span>
            </span>
        </div>
        <div style="background: white; padding: 32px; border-radius: 12px; box-shadow: 0 1px 3px rgba(0,0,0,0.08);">
            <h2 style="margin: 0 0 8px; font-size: 18px; color: #17503F;">Verify Your Email</h2>
            <p style="color: #666; font-size: 14px; margin: 0 0 24px;">Use the code below to complete your registration:</p>
            <div style="text-align: center; padding: 16px; background: #f0f7f4; border-radius: 8px; margin-bottom: 24px;">
                <span style="font-size: 36px; font-weight: 800; letter-spacing: 8px; color: #17503F;">{otp}</span>
            </div>
            <p style="color: #999; font-size: 12px; margin: 0;">This code expires in 10 minutes. If you didn't create an account, ignore this email.</p>
        </div>
    </div>
    """
    _send_email(to_email, "ClipSense - Verify Your Email", html)


def send_forgot_password_otp(to_email: str, otp: str):
    """Send forgot-password OTP email."""
    html = f"""
    <div style="font-family: 'Segoe UI', sans-serif; max-width: 480px; margin: auto; padding: 32px; background: #f8f9fa; border-radius: 16px;">
        <div style="text-align: center; margin-bottom: 24px;">
            <span style="font-size: 28px; font-weight: 800; letter-spacing: -1px;">
                <span style="color: #A89E53;">Clip</span><span style="color: #B7561F;">Sense</span>
            </span>
        </div>
        <div style="background: white; padding: 32px; border-radius: 12px; box-shadow: 0 1px 3px rgba(0,0,0,0.08);">
            <h2 style="margin: 0 0 8px; font-size: 18px; color: #B7561F;">Password Reset</h2>
            <p style="color: #666; font-size: 14px; margin: 0 0 24px;">Use the code below to reset your password:</p>
            <div style="text-align: center; padding: 16px; background: #fdf6f0; border-radius: 8px; margin-bottom: 24px;">
                <span style="font-size: 36px; font-weight: 800; letter-spacing: 8px; color: #B7561F;">{otp}</span>
            </div>
            <p style="color: #999; font-size: 12px; margin: 0;">If you didn't request a password reset, ignore this email. Your password won't be changed.</p>
        </div>
    </div>
    """
    _send_email(to_email, "ClipSense - Password Reset Code", html)


def send_password_change_otp(to_email: str, otp: str):
    """Send password-change OTP email (for logged-in users)."""
    html = f"""
    <div style="font-family: 'Segoe UI', sans-serif; max-width: 480px; margin: auto; padding: 32px; background: #f8f9fa; border-radius: 16px;">
        <div style="text-align: center; margin-bottom: 24px;">
            <span style="font-size: 28px; font-weight: 800; letter-spacing: -1px;">
                <span style="color: #A89E53;">Clip</span><span style="color: #B7561F;">Sense</span>
            </span>
        </div>
        <div style="background: white; padding: 32px; border-radius: 12px; box-shadow: 0 1px 3px rgba(0,0,0,0.08);">
            <h2 style="margin: 0 0 8px; font-size: 18px; color: #A89E53;">Password Change Verification</h2>
            <p style="color: #666; font-size: 14px; margin: 0 0 24px;">You requested to change your password. Use this code to confirm:</p>
            <div style="text-align: center; padding: 16px; background: #faf9ed; border-radius: 8px; margin-bottom: 24px;">
                <span style="font-size: 36px; font-weight: 800; letter-spacing: 8px; color: #A89E53;">{otp}</span>
            </div>
            <p style="color: #999; font-size: 12px; margin: 0;">If you didn't request this, secure your account immediately.</p>
        </div>
    </div>
    """
    _send_email(to_email, "ClipSense - Password Change Verification", html)


def send_processing_complete(to_email: str, project_title: str, clip_count: int, avg_engagement: float):
    """Send notification when video processing is complete."""
    html = f"""
    <div style="font-family: 'Segoe UI', sans-serif; max-width: 480px; margin: auto; padding: 32px; background: #f8f9fa; border-radius: 16px;">
        <div style="text-align: center; margin-bottom: 24px;">
            <span style="font-size: 28px; font-weight: 800; letter-spacing: -1px;">
                <span style="color: #A89E53;">Clip</span><span style="color: #B7561F;">Sense</span>
            </span>
        </div>
        <div style="background: white; padding: 32px; border-radius: 12px; box-shadow: 0 1px 3px rgba(0,0,0,0.08);">
            <h2 style="margin: 0 0 8px; font-size: 18px; color: #17503F;">🎬 Your Clips Are Ready!</h2>
            <p style="color: #666; font-size: 14px; margin: 0 0 24px;">Great news! We've finished processing your video.</p>
            <div style="background: #f0f7f4; padding: 20px; border-radius: 8px; margin-bottom: 24px;">
                <table style="width: 100%; border-collapse: collapse; font-size: 14px;">
                    <tr>
                        <td style="padding: 6px 0; color: #888;">Project</td>
                        <td style="padding: 6px 0; text-align: right; font-weight: 700; color: #333;">{project_title}</td>
                    </tr>
                    <tr>
                        <td style="padding: 6px 0; color: #888;">Clips Generated</td>
                        <td style="padding: 6px 0; text-align: right; font-weight: 700; color: #A89E53;">{clip_count}</td>
                    </tr>
                    <tr>
                        <td style="padding: 6px 0; color: #888;">Avg. Engagement</td>
                        <td style="padding: 6px 0; text-align: right; font-weight: 700; color: #B7561F;">{avg_engagement}/10</td>
                    </tr>
                </table>
            </div>
            <p style="color: #999; font-size: 12px; margin: 0;">Log in to your dashboard to view, download, and share your clips.</p>
        </div>
    </div>
    """
    _send_email(to_email, f"ClipSense - Your clips for \"{project_title}\" are ready!", html)
