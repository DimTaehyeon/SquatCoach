import cv2
import mediapipe as mp
from mediapipe.tasks import python
from mediapipe.tasks.python import vision
import json  # JSON 저장을 위한 모듈 추가

# 1. 모델 설정 및 PoseLandmarker 초기화
model_path = 'pose_landmarker_full.task'
base_options = python.BaseOptions(model_asset_path=model_path)

options = vision.PoseLandmarkerOptions(
    base_options=base_options,
    running_mode=vision.RunningMode.VIDEO,
    min_pose_detection_confidence=0.5,
    min_tracking_confidence=0.5
)

# 2. 비디오 파일 열기
video_path = 'sample.mp4'
cap = cv2.VideoCapture(video_path)
fps = cap.get(cv2.CAP_PROP_FPS)

all_frames_data = []
frame_count = 0

# 3. PoseLandmarker 실행 및 랜드마크 추출
with vision.PoseLandmarker.create_from_options(options) as landmarker:
    while cap.isOpened():
        ret, frame = cap.read()
        if not ret:
            break
            
        frame_count += 1
        
        image_rgb = cv2.cvtColor(frame, cv2.COLOR_BGR2RGB)
        mp_image = mp.Image(image_format=mp.ImageFormat.SRGB, data=image_rgb)
        
        # 타임스탬프 계산 및 8초 구간 제한
        frame_timestamp_ms = int(1000 * frame_count / fps)
        if frame_timestamp_ms > 8000:
            print("8초 구간에 도달하여 분석을 조기 종료합니다.")
            break
            
        results = landmarker.detect_for_video(mp_image, frame_timestamp_ms)
        
        # 랜드마크 인식 및 핵심 관절 필터링 (어깨 포함)
        if results.pose_landmarks:
            landmarks = results.pose_landmarks[0]
            
            target_joints = {
                "left_shoulder": 11, "right_shoulder": 12,
                "left_hip": 23, "right_hip": 24,
                "left_knee": 25, "right_knee": 26,
                "left_ankle": 27, "right_ankle": 28
            }
            
            filtered_landmarks = {}
            for joint_name, index in target_joints.items():
                lm = landmarks[index]
                filtered_landmarks[joint_name] = {
                    "x": lm.x,
                    "y": lm.y,
                    "z": lm.z,
                    "visibility": lm.visibility
                }
            
            all_frames_data.append({
                "frame": frame_count,
                "timestamp_ms": frame_timestamp_ms,
                "landmarks": filtered_landmarks
            })

cap.release()

# 4. 추출된 데이터를 JSON 파일로 저장 (1-4 단계)
output_filename = 'reference_squat.json'
with open(output_filename, 'w', encoding='utf-8') as f:
    # indent=4를 주어 사람이 읽기 쉽고 직관적인 계층 구조로 포맷팅
    json.dump(all_frames_data, f, ensure_ascii=False, indent=4)

print(f"\n총 {len(all_frames_data)}개 프레임의 기준 데이터가 '{output_filename}'에 성공적으로 저장되었습니다.")