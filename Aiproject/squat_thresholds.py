# [하체 오류 판정 기준]
KNEE_CAVING = {"warning": 1.0, "error": 0.8}    # 다리 모아짐 (무릎 간격 / 발목 간격)
DEPTH_LACK = {"warning": 0.75, "error": 0.60}   # 무릎 덜 굽힘 (엉덩이 하강 / 허벅지 길이)

# [상체 오류 판정 기준]
SHOULDER_TILT = {"warning": 5.0, "error": 10.0} # 몸이 좌우로 기울어짐 (어깨 각도)
PELVIS_TILT = {"warning": 0.08, "error": 0.15}  # 골반 좌우 높이 차 비율
PELVIS_SHIFT = {"warning": 0.10, "error": 0.20} # 골반 중심 이동 비율