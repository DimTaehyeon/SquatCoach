import numpy as np
import tensorflow as tf
import pickle
import pandas as pd

# 1. TFLite 모델 로드 및 인터프리터 초기화 (모바일 앱이 하는 역할)
tflite_model_path = "squat_model.tflite"
interpreter = tf.lite.Interpreter(model_path=tflite_model_path)
interpreter.allocate_tensors()

# 2. 입출력 텐서(데이터 통로) 정보 확인
input_details = interpreter.get_input_details()
output_details = interpreter.get_output_details()

print(f"입력 형태(Shape): {input_details[0]['shape']}")
print(f"출력 형태(Shape): {output_details[0]['shape']}")

# 3. 데이터 스케일러 로드 (학습 때 사용한 기준점)
with open('scaler.pkl', 'rb') as f:
    scaler = pickle.load(f)

# 4. 테스트용 데이터 준비 (squat_features_augmented.csv의 첫 번째 줄 데이터를 활용)
# 실제로는 추출된 12개의 각도/비율 피처 배열이 들어갑니다.
df = pd.read_csv("squat_features_augmented.csv")
sample_data = df.drop(columns=['video_file', 'frame', 'label']).iloc[0:1].values
real_label = df['label'].iloc[0]

# 5. 데이터 스케일링 (필수: 모델은 스케일링된 숫자만 이해함)
scaled_data = scaler.transform(sample_data).astype(np.float32)

# 6. TFLite 모델에 데이터 주입 및 실행 (추론)
interpreter.set_tensor(input_details[0]['index'], scaled_data)
interpreter.invoke()

# 7. 결과 확인
output_data = interpreter.get_tensor(output_details[0]['index'])
predicted_class = np.argmax(output_data)
confidence = output_data[0][predicted_class] * 100

print("\n--- 🎯 추론 결과 ---")
print(f"실제 정답 라벨: {real_label}")
print(f"AI가 예측한 라벨: {predicted_class}")
print(f"예측 확신도(Confidence): {confidence:.2f}%")
print(f"전체 확률 분포: {np.round(output_data[0] * 100, 2)}")