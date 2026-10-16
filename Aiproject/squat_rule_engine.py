import collections
import numpy as np
# 1번 파일에서 설정값(숫자)들을 불러옵니다.
from squat_thresholds import KNEE_CAVING, DEPTH_LACK, SHOULDER_TILT 

knee_caving_buffer = collections.deque(maxlen=3)

def calculate_baseline(frames_2_seconds):
    # 영점 조절 로직 작성...
    pass

def analyze_current_frame(landmarks, baseline):
    # 여기서 불러온 KNEE_CAVING["error"] 등의 숫자를 사용하여 수식을 계산합니다.
    knee_width = abs(landmarks[25].x - landmarks[26].x)
    ankle_width = abs(landmarks[27].x - landmarks[28].x)
    
    caving_ratio = knee_width / ankle_width if ankle_width > 0 else 1.0
    
    if caving_ratio < KNEE_CAVING["error"]:
        knee_caving_buffer.append("ERROR")
    # ... 이하 판정 로직