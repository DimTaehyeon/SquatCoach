import json
import numpy as np

def calculate_angle_3d(a, b, c):
    """
    세 점(a, b, c)의 딕셔너리 데이터를 받아 b(가운데 관절)의 3D 꺾임 각도를 계산합니다.
    예: a=고관절, b=무릎, c=발목 -> 무릎이 굽혀진 각도 반환
    """
    # 딕셔너리에서 x, y, z 값을 추출해 NumPy 배열(벡터)로 변환
    a = np.array([a['x'], a['y'], a['z']])
    b = np.array([b['x'], b['y'], b['z']])
    c = np.array([c['x'], c['y'], c['z']])
    
    # 두 개의 벡터 생성 (b에서 a로 향하는 벡터, b에서 c로 향하는 벡터)
    ba = a - b
    bc = c - b
    
    # 벡터의 내적(Dot Product)과 크기(Norm)를 이용해 코사인 값 계산
    cosine_angle = np.dot(ba, bc) / (np.linalg.norm(ba) * np.linalg.norm(bc))
    
    # 부동소수점 연산 오차로 인해 -1.0 ~ 1.0 범위를 아주 미세하게 벗어나는 것을 방지
    cosine_angle = np.clip(cosine_angle, -1.0, 1.0)
    
    # 아크코사인(arccos)을 통해 라디안 값을 구하고, 사람이 읽기 쉬운 degree(도)로 변환
    angle = np.degrees(np.arccos(cosine_angle))
    return angle

# 1. 1단계에서 저장해둔 JSON 데이터 불러오기
json_file_path = 'reference_squat.json'
with open(json_file_path, 'r', encoding='utf-8') as f:
    reference_data = json.load(f)

angle_series_data = []

# 2. 전체 시계열 데이터를 순회하며 프레임별 각도 계산
for frame_data in reference_data:
    landmarks = frame_data['landmarks']
    
    # 왼쪽 하체 기준 (고관절, 무릎, 발목)
    left_hip = landmarks['left_hip']
    left_knee = landmarks['left_knee']
    left_ankle = landmarks['left_ankle']
    
    # 무릎 각도 계산 함수 호출
    knee_angle = calculate_angle_3d(left_hip, left_knee, left_ankle)
    
    angle_series_data.append({
        "frame": frame_data['frame'],
        "timestamp_ms": frame_data['timestamp_ms'],
        "left_knee_angle": round(knee_angle, 2)
    })

# 3. 데이터 전처리 결과 확인 (처음 5개 프레임 및 각도의 최솟값 분석)
print("✅ JSON 데이터 로드 및 프레임별 무릎 각도 계산 완료\n")
print("[초기 5프레임 각도]")
for data in angle_series_data[:5]:
    print(f"프레임 {data['frame']:02d} ({data['timestamp_ms']}ms) : {data['left_knee_angle']}도")

# 스쿼트의 '깊이'를 판단하기 위해 가장 많이 구부러졌을 때(최소 각도) 추출
min_angle_frame = min(angle_series_data, key=lambda x: x['left_knee_angle'])
print(f"\n[스쿼트 최대 지점 (가장 깊게 앉은 순간)]")
print(f"시간: {min_angle_frame['timestamp_ms']}ms, 각도: {min_angle_frame['left_knee_angle']}도")