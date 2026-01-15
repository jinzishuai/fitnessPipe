#!/usr/bin/env python3
"""
Extract pose landmarks from any fitness video using MediaPipe.

This script processes a video file and extracts all 33 pose landmarks
per frame, then generates a Dart fixture file for testing.

Requirements:
    pip install opencv-python mediapipe numpy

Usage:
    python extract_poses.py --video <path_to_video> --output <path_to_dart_file> --name <variable_prefix>
    
Example:
    python extract_poses.py --video single_squat.mp4 --output real_single_squat.dart --name RealSingleSquat
"""

import cv2
import mediapipe as mp
from mediapipe.tasks import python
from mediapipe.tasks.python import vision
import argparse
from datetime import datetime
from pathlib import Path
from typing import List, Dict, Any
import math
import sys

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
    # Expect model in the same directory as script
    model_path = str(Path(__file__).parent / "pose_landmarker.task")
    if not Path(model_path).exists():
        # Fallback to looking in current directory
        if Path("pose_landmarker.task").exists():
            model_path = "pose_landmarker.task"
        else:
             print(f"WARNING: Model not found at {model_path}. Please download pose_landmarker.task")

    try:
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
                if frame_idx % 30 == 0:
                    print(f"  Processed {frame_idx}/{frame_count} frames...", end='\r')
                    
    except Exception as e:
        print(f"\nError initializing MediaPipe: {e}")
        raise
    
    cap.release()
    print(f"\n  Extracted: {len(frames_data)} frames with pose data")
    
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

def generate_dart_fixture(data: Dict[str, Any], output_path: str, variable_prefix: str) -> None:
    """Generate Dart fixture file from extracted data."""
    
    # Ensure camelCase for variable names (e.g. RealLateralRaise -> realLateralRaise)
    # If user provided CamelCase, convert first char to lower
    if variable_prefix and variable_prefix[0].isupper():
        prefix_lower = variable_prefix[0].lower() + variable_prefix[1:]
    else:
        prefix_lower = variable_prefix

    metadata_var = f"{prefix_lower}Metadata"
    frames_var = f"{prefix_lower}Frames"

    with open(output_path, 'w') as f:
        f.write("// GENERATED FILE - DO NOT EDIT\n")
        f.write("// Generated by extract_poses.py\n")
        f.write(f"// Source: {data['metadata']['source_video']}\n")
        f.write(f"// Extracted: {data['metadata']['extracted_at']}\n\n")
        
        f.write("import 'package:fitness_counter/fitness_counter.dart';\n\n")
        
        # Write metadata
        f.write("/// Metadata about the source video.\n")
        f.write(f"final Map<String, dynamic> {metadata_var} = {{\n")
        for key, value in data['metadata'].items():
            if isinstance(value, str):
                f.write(f"  '{key}': '{value}',\n")
            else:
                f.write(f"  '{key}': {value},\n")
        f.write("};\n\n")
        
        # Write frames
        f.write(f"/// Real pose data extracted from {data['metadata']['source_video']}.\n")
        f.write("///\n")
        f.write(f"/// Contains {len(data['frames'])} frames from a {data['metadata']['duration_seconds']:.2f}s video.\n")
        f.write(f"final List<PoseFrame> {frames_var} = [\n")
        
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
    print(f"  Variables: {metadata_var}, {frames_var}")

def main():
    parser = argparse.ArgumentParser(description='Extract pose landmarks from video to Dart fixture.')
    parser.add_argument('--video', required=True, help='Path to input video file')
    parser.add_argument('--output', required=True, help='Path to output Dart file')
    parser.add_argument('--name', required=True, help='Prefix for Dart variables (e.g. "realSingleSquat")')
    parser.add_argument('--export-images', action='store_true', help='Export frames as JPEG images')

    args = parser.parse_args()
    
    video_path = Path(args.video)
    output_path = Path(args.output)
    
    if not video_path.exists():
        print(f"ERROR: Video file not found: {video_path}")
        return 1
    
    try:
        # Extract landmarks
        data = extract_landmarks_from_video(str(video_path))
        
        # Generate Dart fixture
        generate_dart_fixture(data, str(output_path), args.name)
        
        # Export images if requested
        if args.export_images:
            output_dir = output_path.parent / "images"
            output_dir.mkdir(exist_ok=True)
            
            print(f"\nExporting images to {output_dir}...")
            cap = cv2.VideoCapture(str(video_path))
            
            # Use data['frames'] to only export frames where we successfully detected a pose
            # Or just export all frames that match the fixture indices.
            # Let's export all frames that correspond to the data we extracted to keep indices in sync.
            
            # Map frame_number to frame data for quick lookup
            frames_to_export = {f['frame_number'] for f in data['frames']}
            
            frame_idx = 0
            exported_count = 0
            while cap.isOpened():
                ret, frame = cap.read()
                if not ret:
                    break
                
                if frame_idx in frames_to_export:
                    # Save as jpg
                    image_path = output_dir / f"frame_{frame_idx}.jpg"
                    cv2.imwrite(str(image_path), frame)
                    exported_count += 1
                
                frame_idx += 1
                
            cap.release()
            print(f"  Exported {exported_count} images matching extracted poses.")

        print("\n✓ Extraction complete!")
        return 0
        
    except Exception as e:
        print(f"\nERROR: {e}")
        import traceback
        traceback.print_exc()
        return 1

if __name__ == "__main__":
    sys.exit(main())
