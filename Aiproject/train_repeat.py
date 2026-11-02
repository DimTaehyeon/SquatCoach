import os
import pandas as pd
import numpy as np
from sklearn.model_selection import train_test_split
from sklearn.preprocessing import StandardScaler
import tensorflow as tf
import pickle

# 1. 완벽하게 정제된 데이터셋 로드
file_path = "squat_features_augmented.csv"
df = pd.read_csv(file_path)

# 2. 피처(X)와 라벨(y) 분리
X = df.drop(columns=['video_file', 'frame', 'label'])
y = df['label']

# 3. 데이터 9:1 분할 (학습용 90%, 시험용 10%로 변경)
# test_size를 0.1로 설정하여 최대한 많은 데이터를 학습에 집중시킵니다.
X_train, X_test, y_train, y_test = train_test_split(X, y, test_size=0.1, random_state=42, stratify=y)

# 4. 데이터 스케일링
scaler = StandardScaler()
X_train_scaled = scaler.fit_transform(X_train)
X_test_scaled = scaler.transform(X_test)

with open('scaler.pkl', 'wb') as f:
    pickle.dump(scaler, f)

# ==========================================
# 5. 기존 학습 모델(.keras) 로드 OR 새로운 모델 생성
# ==========================================
keras_model_path = 'squat_keras_model.keras'
num_classes = len(np.unique(y))

if os.path.exists(keras_model_path):
    print(f"🔄 [누적 학습 모드] 기존 학습 원본 파일('{keras_model_path}')을 이어서 학습합니다.")
    model = tf.keras.models.load_model(keras_model_path)
else:
    print("✨ [신규 학습 모드] 저장된 모델이 없습니다. 모델을 처음부터 학습합니다.")
    model = tf.keras.Sequential([
        tf.keras.layers.Input(shape=(X_train_scaled.shape[1],)),
        tf.keras.layers.Dense(128, activation='relu'),
        tf.keras.layers.Dropout(0.3),
        tf.keras.layers.Dense(64, activation='relu'),
        tf.keras.layers.Dropout(0.2),
        tf.keras.layers.Dense(32, activation='relu'),
        tf.keras.layers.Dense(num_classes, activation='softmax')
    ])
    model.compile(optimizer=tf.keras.optimizers.Adam(learning_rate=0.001),
                  loss='sparse_categorical_crossentropy',
                  metrics=['accuracy'])

# 6. 조기 종료(Early Stopping) 부활 및 에포크 확장 적용
# 10%의 테스트 데이터가 있으므로, 다시 'val_loss'를 기준으로 실력을 평가합니다.
early_stop = tf.keras.callbacks.EarlyStopping(
    monitor='val_loss', 
    patience=20, # 에포크를 늘렸으므로, 실력이 안 올라도 20번까지는 더 시도해 보도록 인내심 부여
    restore_best_weights=True
)

print("🚀 90% 데이터로 대규모 학습을 시작합니다... (나머지 10%는 과적합 검증용)")
history = model.fit(
    X_train_scaled, y_train, 
    epochs=200,            # 요청하신 대로 최대 200번까지 학습 기회 부여
    batch_size=32, 
    validation_data=(X_test_scaled, y_test), # 10% 데이터를 실시간 모의고사용으로 투입
    callbacks=[early_stop], 
    verbose=1
)

# 7. 훈련 가중치 저장 (.keras 원본)
model.save(keras_model_path)
print(f"\n💾 누적 학습을 위한 원본 모델을 '{keras_model_path}'에 안전하게 저장했습니다.")

# 8. 최종 정확도 평가
loss, accuracy = model.evaluate(X_test_scaled, y_test, verbose=0)
print(f"✅ 학습 완료! 10%의 처음 보는 테스트 데이터 예측 정확도: {accuracy * 100:.2f}%")

# ==========================================
# 9. 앱 탑재용 TensorFlow Lite (.tflite) 변환 및 덮어쓰기
# ==========================================
converter = tf.lite.TFLiteConverter.from_keras_model(model)
tflite_model = converter.convert()

tflite_filename = 'squat_model.tflite'
with open(tflite_filename, 'wb') as f:
    f.write(tflite_model)

print(f"📦 Flutter 앱 연동용 파일 덮어쓰기 완료: '{tflite_filename}' (크기: {len(tflite_model)} 바이트)")