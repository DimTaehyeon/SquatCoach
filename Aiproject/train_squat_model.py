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
# 학습에 불필요한 메타데이터(문자열 경로, 프레임 번호)를 제외하고 '숫자 각도'만 남깁니다.
X = df.drop(columns=['video_file', 'frame', 'label'])
y = df['label']

# 3. 데이터 분할 (학습용 80%, 시험용 20%)
X_train, X_test, y_train, y_test = train_test_split(X, y, test_size=0.2, random_state=42, stratify=y)

# 4. 데이터 스케일링 (신경망 학습 안정화 및 속도 향상)
scaler = StandardScaler()
X_train_scaled = scaler.fit_transform(X_train)
X_test_scaled = scaler.transform(X_test)

# 모바일 앱에서 동일한 기준으로 변환하기 위해 스케일러 저장
with open('scaler.pkl', 'wb') as f:
    pickle.dump(scaler, f)

# 5. 넓은(Wide) 신경망으로 재설계 (정형 데이터에 유리)
num_classes = len(np.unique(y))

model = tf.keras.Sequential([
    tf.keras.layers.Input(shape=(X_train_scaled.shape[1],)),
    tf.keras.layers.Dense(128, activation='relu'), # 64 -> 128로 대폭 확장
    tf.keras.layers.Dropout(0.3), # 과적합을 막기 위해 드롭아웃 비율 약간 상승
    
    tf.keras.layers.Dense(64, activation='relu'),
    tf.keras.layers.Dropout(0.2),
    
    tf.keras.layers.Dense(32, activation='relu'),
    tf.keras.layers.Dense(num_classes, activation='softmax')
])

model.compile(optimizer=tf.keras.optimizers.Adam(learning_rate=0.001),
              loss='sparse_categorical_crossentropy',
              metrics=['accuracy'])

print("🚀 넓은(Wide) 구조의 신경망으로 재학습을 시작합니다...")

# 6. 콜백 단순화
early_stop = tf.keras.callbacks.EarlyStopping(
    monitor='val_loss', 
    patience=15, 
    restore_best_weights=True
)

history = model.fit(
    X_train_scaled, y_train, 
    epochs=100,
    batch_size=32, 
    validation_split=0.2,
    callbacks=[early_stop], 
    verbose=1
)
# 7. 테스트 데이터를 통한 최종 정확도 평가
loss, accuracy = model.evaluate(X_test_scaled, y_test, verbose=0)
print(f"\n✅ 학습 완료! 처음 보는 테스트 데이터 예측 정확도: {accuracy * 100:.2f}%")

# 8. 대망의 TensorFlow Lite (.tflite) 변환 및 저장
converter = tf.lite.TFLiteConverter.from_keras_model(model)
tflite_model = converter.convert()

tflite_filename = 'squat_model.tflite'
with open(tflite_filename, 'wb') as f:
    f.write(tflite_model)

print(f"📦 Flutter 연동용 파일 저장 완료: '{tflite_filename}' (크기: {len(tflite_model)} 바이트)")