#!/usr/bin/env python3
"""
Extract pose landmarks from single squat video using MediaPipe.

This script processes a video file and extracts all 33 pose landmarks
per frame, then generates a Dart fixture file for testing.

Requirements:
    pip install opencv-python mediapipe numpy

Usage:
    python extract_squat_poses.py
"""

import cv2
import mediapipe as mp
from mediapipe.tasks import python
from mediapipe.tasks.python import vision
import json
from datetime import datetime
from pathlib import Path
from typing import List, Dict, Any
import math

# Landmark names matching Dart enum LandmarkId
LANDMARK_NAMES = [
    'nose', 'leftEyeInner', 'leftEye', 'leftEyeOuter',
    'rightEyeInner', 'rightEye', 'rightEyeOuter',
    'leftEar', 'rightEar', 'mouthLeft', 'mouthRight',
    'leftShoulder', 'rightShoulder', 'leftElbow', 'rightElbow',
    'leftWrist', 'rightWrist', 'leftPinky', 'rightPinky',
    'leftIndex', 'rightIndex', 'leftThumb', 'rightThumb',
    'leftHip', 'rightHip', 'leftKnee', 'rightKnee',
    'leftAnkle', 'rightAnkle', 'leftHeel', 'rightHeel',
    'leftFootIndex', 'rightFootIndex'
]


def extract_landmarks_from_video(video_path: str) -> Dict[str, Any]:
    """Extract pose landmarks from video file using MediaPipe Task API."""
    cap = cv2.VideoCapture(video_path)
    
    if not cap.isOpened():
        raise ValueError(f"Could not open video file: {video_path}")
    
    fps = cap.get(cv2.CAP_PROP_FPS)
    frame_count = int(cap.get(cv2.CAP_PROP_FRAME_COUNT))
    duration = frame_count / fps if fps > 0 else 0
    
    print(f"Processing video: {Path(video_path).name}")
    print(f"  FPS: {fps}")
    print(f"  Frames: {frame_count}")
    print(f"  Duration: {duration:.2f}s")
    
    # Create PoseLandmarker
    model_path = str(Path(__file__).parent / "pose_landmarker.task")
    base_options = python.BaseOptions(model_asset_path=model_path)
    options = vision.PoseLandmarkerOptions(
        base_options=base_options,
        running_mode=vision.RunningMode.VIDEO,
        min_pose_detection_confidence=0.5,
        min_pose_presence_confidence=0.5,
        min_tracking_confidence=0.5
    )
    
    frames_data = []
    frame_idx = 0
    
    with vision.PoseLandmarker.create_from_options(options) as landmarker:
        while cap.isOpened():
            ret, frame = cap.read()
            if not ret:
                break
            
            # Convert BGR to RGB
            rgb_frame = cv2.cvtColor(frame, cv2.COLOR_BGR2RGB)
            mp_image = mp.Image(image_format=mp.ImageFormat.SRGB, data=rgb_frame)
            
            # Process with MediaPipe (timestamp in milliseconds)
            timestamp_ms = int((frame_idx / fps) * 1000) if fps > 0 else frame_idx * 33
            results = landmarker.detect_for_video(mp_image, timestamp_ms)
            
            if results.pose_landmarks:
                # Extract all 33 landmarks from first detected pose
                landmarks = {}
                for idx, landmark in enumerate(results.pose_landmarks[0]):
                    if idx < len(LANDMARK_NAMES):
                        landmarks[LANDMARK_NAMES[idx]] = {
                            'x': landmark.x,
                            'y': landmark.y,
                            'z': landmark.z,
                            'confidence': landmark.visibility if hasattr(landmark, 'visibility') else 1.0
                        }
                
                frames_data.append({
                    'frame_number': frame_idx,
                    'timestamp_ms': timestamp_ms,
                    'landmarks': landmarks
                })
            
            frame_idx += 1
    
    cap.release()
    
    print(f"  Extracted: {len(frames_data)} frames with pose data")
    
    return {
        'metadata': {
            'source_video': str(Path(video_path).name),
            'fps': fps,
            'total_frames': frame_count,
            'frames_with_pose': len(frames_data),
            'duration_seconds': duration,
            'extracted_at': datetime.now().isoformat()
        },
        'frames': frames_data
    }


def calculate_knee_angle(landmarks: Dict[str, Dict]) -> float:
    """Calculate average knee angle (hip-knee-ankle) for validation."""
    def angle_from_landmarks(hip, knee, ankle):
        if not all([hip, knee, ankle]):
            return 0.0
        
        # Vector from knee to hip
        thigh_x = hip['x'] - knee['x']
        thigh_y = hip['y'] - knee['y']
        
        # Vector from knee to ankle
        shin_x = ankle['x'] - knee['x']
        shin_y = ankle['y'] - knee['y']
        
        # Calculate angle
        thigh_angle = math.atan2(thigh_y, thigh_x)
        shin_angle = math.atan2(shin_y, shin_x)
        
        angle_rad = abs(thigh_angle - shin_angle)
        angle_deg = math.degrees(angle_rad)
        
        # Normalize to 0-180 range
        if angle_deg > 180:
            angle_deg = 360 - angle_deg
            
        return angle_deg
    
    left_angle = angle_from_landmarks(
        landmarks.get('leftHip'),
        landmarks.get('leftKnee'),
        landmarks.get('leftAnkle')
    )
    
    right_angle = angle_from_landmarks(
        landmarks.get('rightHip'),
        landmarks.get('rightKnee'),
        landmarks.get('rightAnkle')
    )
    
    if left_angle > 0 and right_angle > 0:
        return (left_angle + right_angle) / 2
    return left_angle or right_angle


def analyze_extracted_data(data: Dict[str, Any]) -> None:
    """Analyze and print statistics about extracted data."""
    frames = data['frames']
    
    if not frames:
        print("WARNING: No pose data extracted!")
        return
    
    # Calculate angles for all frames
    angles = []
    for frame in frames:
        angle = calculate_knee_angle(frame['landmarks'])
        angles.append(angle)
    
    if not angles:
        print("WARNING: No angles calculated!")
        return

    min_angle = min(angles)
    max_angle = max(angles)
    avg_angle = sum(angles) / len(angles)
    
    print(f"\nAnalysis:")
    print(f"  Knee Angle range: {min_angle:.1f}° - {max_angle:.1f}°")
    print(f"  Average angle: {avg_angle:.1f}°")
    
    # Detect Squat (Valleys for squat, as angle decreases when squatting)
    valleys = 0
    # Approx standing is ~170-180, squat bottom is ~70-90
    threshold = 120 
    
    was_below = angles[0] < threshold
    
    for angle in angles[1:]:
        is_below = angle < threshold
        if not was_below and is_below:
            valleys += 1
        was_below = is_below
    
    print(f"  Detected squats (valleys): {valleys} (approximate rep count)")


def generate_dart_fixture(data: Dict[str, Any], output_path: str) -> None:
    """Generate Dart fixture file from extracted data."""
    
    with open(output_path, 'w') as f:
        f.write("// GENERATED FILE - DO NOT EDIT\n")
        f.write("// Generated by extract_squat_poses.py\n")
        f.write(f"// Source: {data['metadata']['source_video']}\n")
        f.write(f"// Extracted: {data['metadata']['extracted_at']}\n\n")
        
        f.write("import 'package:fitness_counter/fitness_counter.dart';\n\n")
        
        # Write metadata
        f.write("/// Metadata about the source video.\n")
        f.write("final Map<String, dynamic> realSingleSquatMetadata = {\n")
        for key, value in data['metadata'].items():
            if isinstance(value, str):
                f.write(f"  '{key}': '{value}',\n")
            else:
                f.write(f"  '{key}': {value},\n")
        f.write("};\n\n")
        
        # Write frames
        f.write("/// Real pose data extracted from single squat video.\n")
        f.write("///\n")
        f.write(f"/// Contains {len(data['frames'])} frames from a {data['metadata']['duration_seconds']:.2f}s video.\n")
        f.write("final List<PoseFrame> realSingleSquatFrames = [\n")
        
        for frame in data['frames']:
            timestamp_ms = frame['timestamp_ms']
            landmarks = frame['landmarks']
            
            f.write(f"  // Frame {frame['frame_number']} @ {timestamp_ms}ms\n")
            f.write(f"  PoseFrame(\n")
            f.write(f"    timestamp: DateTime.fromMillisecondsSinceEpoch({timestamp_ms}),\n")
            f.write(f"    landmarks: {{\n")
            
            for name, lm in landmarks.items():
                f.write(f"      LandmarkId.{name}: Landmark(\n")
                f.write(f"        x: {lm['x']:.6f},\n")
                f.write(f"        y: {lm['y']:.6f},\n")
                f.write(f"        z: {lm['z']:.6f},\n")
                f.write(f"        confidence: {lm['confidence']:.6f},\n")
                f.write(f"      ),\n")
            
            f.write(f"    }},\n")
            f.write(f"  ),\n")
        
        f.write("];\n")
    
    print(f"\nGenerated Dart fixture: {output_path}")


def main():
    """Main entry point."""
    script_dir = Path(__file__).parent
    video_path = script_dir / "single_squat.mp4"
    output_path = script_dir / "real_single_squat.dart"
    
    if not video_path.exists():
        print(f"ERROR: Video file not found: {video_path}")
        return 1
    
    try:
        # Extract landmarks
        data = extract_landmarks_from_video(str(video_path))
        
        # Analyze
        analyze_extracted_data(data)
        
        # Generate Dart fixture
        generate_dart_fixture(data, str(output_path))
        
        print("\n✓ Extraction complete!")
        return 0
        
    except Exception as e:
        print(f"\nERROR: {e}")
        import traceback
        traceback.print_exc()
        return 1


if __name__ == "__main__":
    exit(main())
