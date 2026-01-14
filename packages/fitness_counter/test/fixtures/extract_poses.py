#!/usr/bin/env python3
"""
Extract pose landmarks from lateral raise video using MediaPipe.

This script processes a video file and extracts all 33 pose landmarks
per frame, then generates a Dart fixture file for testing.

Requirements:
    pip install opencv-python mediapipe numpy

Usage:
    python extract_poses.py
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


def calculate_shoulder_angle(landmarks: Dict[str, Dict]) -> float:
    """Calculate average shoulder angle for validation."""
    def angle_from_landmarks(shoulder, elbow, hip):
        if not all([shoulder, elbow, hip]):
            return 0.0
        
        # Vector from shoulder to elbow
        arm_x = elbow['x'] - shoulder['x']
        arm_y = elbow['y'] - shoulder['y']
        
        # Vector from shoulder to hip (torso reference)
        torso_x = hip['x'] - shoulder['x']
        torso_y = hip['y'] - shoulder['y']
        
        # Calculate angle
        arm_angle = math.atan2(arm_y, arm_x)
        torso_angle = math.atan2(torso_y, torso_x)
        
        angle_rad = abs(arm_angle - torso_angle)
        angle_deg = math.degrees(angle_rad)
        
        # Normalize to 0-90 range
        if angle_deg > 90:
            angle_deg = 180 - angle_deg
        
        return angle_deg
    
    left_angle = angle_from_landmarks(
        landmarks.get('leftShoulder'),
        landmarks.get('leftElbow'),
        landmarks.get('leftHip')
    )
    
    right_angle = angle_from_landmarks(
        landmarks.get('rightShoulder'),
        landmarks.get('rightElbow'),
        landmarks.get('rightHip')
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
        angle = calculate_shoulder_angle(frame['landmarks'])
        angles.append(angle)
    
    min_angle = min(angles)
    max_angle = max(angles)
    avg_angle = sum(angles) / len(angles)
    
    print(f"\nAnalysis:")
    print(f"  Angle range: {min_angle:.1f}° - {max_angle:.1f}°")
    print(f"  Average angle: {avg_angle:.1f}°")
    
    # Detect peaks (simple peak detection for rep counting)
    peaks = 0
    threshold = avg_angle
    was_above = angles[0] > threshold
    
    for angle in angles[1:]:
        is_above = angle > threshold
        if was_above and not is_above:
            peaks += 1
        was_above = is_above
    
    print(f"  Detected peaks: {peaks} (approximate rep count)")


def generate_dart_fixture(data: Dict[str, Any], output_path: str) -> None:
    """Generate Dart fixture file from extracted data."""
    
    with open(output_path, 'w') as f:
        f.write("// GENERATED FILE - DO NOT EDIT\n")
        f.write("// Generated by extract_poses.py\n")
        f.write(f"// Source: {data['metadata']['source_video']}\n")
        f.write(f"// Extracted: {data['metadata']['extracted_at']}\n\n")
        
        f.write("import 'package:fitness_counter/fitness_counter.dart';\n\n")
        
        # Write metadata
        f.write("/// Metadata about the source video.\n")
        f.write("final Map<String, dynamic> realLateralRaiseMetadata = {\n")
        for key, value in data['metadata'].items():
            if isinstance(value, str):
                f.write(f"  '{key}': '{value}',\n")
            else:
                f.write(f"  '{key}': {value},\n")
        f.write("};\n\n")
        
        # Write frames
        f.write("/// Real pose data extracted from lateral raise video.\n")
        f.write("///\n")
        f.write(f"/// Contains {len(data['frames'])} frames from a {data['metadata']['duration_seconds']:.2f}s video.\n")
        f.write("final List<PoseFrame> realLateralRaiseFrames = [\n")
        
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
    video_path = script_dir / "LateralRaise_One_Rep.mp4"
    output_path = script_dir / "real_lateral_raise.dart"
    
    # Check local directory first, then Documents folder
    if not video_path.exists():
        alt_path = Path.home() / "Documents" / "LateralRaise_One_Rep.mp4"
        if alt_path.exists():
            print(f"Using video from: {alt_path}")
            video_path = alt_path
        else:
            print(f"ERROR: Video file not found in:")
            print(f"  - {script_dir / 'LateralRaise_One_Rep.mp4'}")
            print(f"  - {alt_path}")
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
