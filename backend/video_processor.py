import os
import cv2
import numpy as np
import mediapipe as mp
from PIL import Image, ImageDraw, ImageFont
from moviepy.editor import VideoFileClip, TextClip, CompositeVideoClip, AudioFileClip
from moviepy.video.io.VideoFileClip import VideoFileClip

# Fix for some environments where mp.solutions is not loaded automatically
try:
    from mediapipe.python import solutions as mp_solutions
except ImportError:
    mp_solutions = mp.solutions if hasattr(mp, "solutions") else None

def detect_face_center(frame, face_detection):
    """Detects the center x-coordinate of the largest face in the frame."""
    try:
        rgb_frame = cv2.cvtColor(frame, cv2.COLOR_BGR2RGB)
        results = face_detection.process(rgb_frame)
        
        if results.detections:
            # Find the largest detection
            largest_detection = max(results.detections, key=lambda d: d.location_data.relative_bounding_box.width * d.location_data.relative_bounding_box.height)
            bbox = largest_detection.location_data.relative_bounding_box
            center_x = bbox.xmin + (bbox.width / 2)
            return center_x
    except Exception as e:
        pass
    return 0.5 # Default to center

import textwrap

def burn_subtitles(clip, segments):
    """
    Burns standard captions into the video.
    segments: list of dicts with 'start', 'end', 'text'
    """
    def make_text_frame(get_frame, t):
        frame = get_frame(t)
        
        # Find the active segment
        active_seg = None
        for seg in segments:
            if seg['start'] <= t <= seg['end']:
                active_seg = seg
                break
        
        if not active_seg:
            return frame
            
        # Convert to PIL
        pil_img = Image.fromarray(frame)
        draw = ImageDraw.Draw(pil_img)
        w, h = pil_img.size
        
        # Standard Style: Centered, White with Black Outline
        fontsize = int(h * 0.05) # 5% of height
        try:
            # Common Windows fonts
            font_paths = [
                "C:\\Windows\\Fonts\\arialbd.ttf", # Arial Bold
                "C:\\Windows\\Fonts\\arial.ttf",
                "C:\\Windows\\Fonts\\segoeui.ttf",
                "/usr/share/fonts/truetype/liberation/LiberationSans-Bold.ttf"
            ]
            font = None
            for p in font_paths:
                if os.path.exists(p):
                    font = ImageFont.truetype(p, fontsize)
                    break
            if not font: font = ImageFont.load_default()
        except:
            font = ImageFont.load_default()

        text = active_seg['text'].strip()
        
        # Simple text wrapping
        max_chars = 40
        lines = textwrap.wrap(text, width=max_chars)
        
        # Calculate total height
        line_spacing = 5
        line_heights = []
        for line in lines:
            try:
                bbox = draw.textbbox((0, 0), line, font=font)
                line_heights.append(bbox[3] - bbox[1])
            except:
                _, th = draw.textsize(line, font=font)
                line_heights.append(th)
        
        total_text_height = sum(line_heights) + (line_spacing * (len(lines) - 1))
        
        # Start Y position (Low-center)
        y = h * 0.85 - total_text_height
        
        for i, line in enumerate(lines):
            try:
                bbox = draw.textbbox((0, 0), line, font=font)
                lw = bbox[2] - bbox[0]
                lh = bbox[3] - bbox[1]
            except:
                lw, lh = draw.textsize(line, font=font)
            
            x = (w - lw) / 2
            # Draw Outline
            stroke_width = 2
            draw.text((x, y), line, font=font, fill="white", 
                      stroke_width=stroke_width, stroke_fill='black')
            y += lh + line_spacing
            
        return np.array(pil_img)

    return clip.fl(lambda gf, t: make_text_frame(gf, t))


def resize_to_letterbox_vertical(clip, target_w=1080, target_h=1920):
    """
    Resizes the clip to fit inside the target 9:16 box while maintaining aspect ratio (Letterbox).
    Adds black bars.
    """
    # 1. Resize to fit width
    clip_resized = clip.resize(width=target_w)
    
    # If height > target_h (unlikely for landscape, but possible), fit by height
    if clip_resized.h > target_h:
        clip_resized = clip.resize(height=target_h)
        
    # 2. Center on black background
    # Since we avoid full CompositeVideoClip if possible for speed, but here we need it for bars.
    # Note: MoviePy TextClip and CompositeVideoClip can be heavy.
    
    # Calculate position to center
    x_pos = (target_w - clip_resized.w) // 2
    y_pos = (target_h - clip_resized.h) // 2
    
    # Create composite
    # Ideally we'd use a ColorClip as background, but for simplicity/speed let's just make the clip larger?
    # No, Composition is best.
    
    # Workaround if ColorClip is missing imports or robust check: 
    # Just return the resized clip if we don't strictly need the black bars file-size overhead?
    # User said "put the whole frame in the aspect ratio".
    # Vertical platforms handles 9:16.
    
    # Let's try to just use `margin` fx if available, or just Composite.
    final = CompositeVideoClip([clip_resized.set_position("center")], size=(target_w, target_h))
    return final

def crop_to_vertical_with_face_tracking(clip):
    """
    Crops a clip to 9:16 vertical ratio, tracking the face.
    """
    if mp_solutions is None:
        print("MediaPipe solutions not found, defaulting to center crop.")
        w, h = clip.size
        # Fallback calc
        target_w = h * (9/16)
        x1 = (w / 2) - (target_w / 2)
        x2 = (w / 2) + (target_w / 2)
        return clip.crop(x1=x1, y1=0, x2=x2, y2=h)
        
    mp_face_detection = mp_solutions.face_detection
    
    # Use "short range" (0) or "full range" (1). 1 is better for standard videos.
    # We wrap in Try/Except to ensure we ALWAYS return a clip
    try:
        with mp_face_detection.FaceDetection(model_selection=1, min_detection_confidence=0.5) as face_detection:
            w, h = clip.size
            target_ratio = 9/16
            target_w = h * target_ratio
            
            # Sample face positions
            centers = []
            timestamps = [0, clip.duration/2, max(0, clip.duration - 0.1)]
            
            for t in timestamps:
                try:
                    frame = clip.get_frame(t)
                    c = detect_face_center(frame, face_detection)
                    centers.append(c)
                except:
                    centers.append(0.5)
            
            # Average center
            avg_center = sum(centers) / len(centers) if centers else 0.5
            
            # Calculate Crop
            center_pix = avg_center * w
            x1 = center_pix - (target_w / 2)
            x2 = center_pix + (target_w / 2)
            
            # Clamp
            if x1 < 0:
                x1 = 0
                x2 = target_w
            if x2 > w:
                x2 = w
                x1 = w - target_w
                
            return clip.crop(x1=x1, y1=0, x2=x2, y2=h)
            
    except Exception as e:
        print(f"Face tracking crashed: {e}. Fallback to center.")
        w, h = clip.size
        target_w = h * (9/16)
        x1 = (w / 2) - (target_w / 2)
        x2 = (w / 2) + (target_w / 2)
        return clip.crop(x1=x1, y1=0, x2=x2, y2=h)

def process_video(video_path, clips_metadata, transcript_segments=None, output_dir="generated_clips", use_subs=True, max_clip_duration=60, crop_mode="Letterbox"):
    """
    Cuts, Formats (Letterbox/Crop), Enforces Duration, and Adds Subtitles.
    crop_mode: "Letterbox" (All visible) or "Face Tracking" (Zoomed)
    transcript_segments: list of dicts from Whisper {'start': float, 'end': float, 'text': str}
    """
    if not os.path.exists(output_dir):
        os.makedirs(output_dir)

    generated_files = []
    
    try:
        original_clip = VideoFileClip(video_path)
        
        # Ensure max_clip_duration is float for math
        max_clip_duration = float(max_clip_duration)
        
        for i, meta in enumerate(clips_metadata):
            # Cast inputs from DB (DynamoDB Decimals) to floats
            start = float(meta.get('start_time', 0))
            end = float(meta.get('end_time', 0))
            
            # --- Enforce Duration Constraint (Dynamic) ---
            duration = end - start
            if duration > max_clip_duration:
                end = start + max_clip_duration
            
            # 1. Cut
            clip = original_clip.subclip(start, end)
            
            # 2. Aspect Ratio Formatting
            if crop_mode == "Face Tracking" and clip.w > clip.h:
                # Zoom/Crop
                clip = crop_to_vertical_with_face_tracking(clip)
            else:
                # Default: Fit to Screen / Letterbox (User Preference)
                clip = resize_to_letterbox_vertical(clip)
            
            # 3. Burn Subtitles (Real Speech Sync)
            if use_subs:
                clip_subs = []
                if transcript_segments:
                    # Filter segments that are inside this clip's time range
                    for seg in transcript_segments:
                        seg_start = float(seg['start'])
                        seg_end = float(seg['end'])
                        
                        # Check intersection
                        if (seg_start < end) and (seg_end > start):
                            # Adjust relative to clip start
                            rel_start = max(0, seg_start - start)
                            rel_end = min(clip.duration, seg_end - start)
                            
                            clip_subs.append({
                                'start': rel_start,
                                'end': rel_end,
                                'text': seg['text'].strip()
                            })
                
                # Fallback if no transcript provided or no speech found in segment
                if not clip_subs:
                     text_content = meta.get('quote') or meta.get('summary') or ""
                     if text_content:
                        clip_subs = [{'start': 0, 'end': clip.duration, 'text': text_content}]
                
                if clip_subs:
                    clip = burn_subtitles(clip, clip_subs)

            output_filename = os.path.join(output_dir, f"clip_{i+1}_{int(start)}.mp4")
            clip.write_videofile(output_filename, codec="libx264", audio_codec="aac")
            generated_files.append(output_filename)
            # Explicitly close subclip to free memory/handles
            clip.close()
            
        return generated_files

    except Exception as e:
        print(f"Error processing video: {e}")
        import traceback
        traceback.print_exc()
        return []
    finally:
        if 'original_clip' in locals():
            original_clip.close()
            print("Successfully closed original_clip handle.")
