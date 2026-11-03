"""
SquatCoach AI 모델 인식률(정확도) 확인

모델 파일(squat_model.tflite, scaler.pkl)은 읽기만 하고 절대 바꾸지 않습니다.
(train_*.py 와 달리 실행해도 앱에 들어간 모델이 덮어써지지 않음)

사용법 (Aiproject 폴더에서):
    python evaluate_model.py

출력:
    1) 테스트 데이터 정확도 (train_repeat.py 와 같은 10% 분할)
    2) 전체 데이터 정확도
    3) 자세별 정확도
    4) 평균 예측 확신도 (모델이 고른 답의 확률 평균)
    5) 영상별 정확도 (어떤 영상에서 잘 틀리는지)

⚠️ 주의: 이 데이터는 같은 프레임을 각도만 바꿔 6개 라벨로 만든 것이라
   테스트 프레임과 거의 같은 프레임이 학습에도 들어 있습니다.
   그래서 여기 나오는 숫자는 '처음 보는 사람/영상' 기준 정확도보다 높게 나올 수 있습니다.
"""
import pickle
import warnings

import numpy as np
import pandas as pd
from sklearn.model_selection import train_test_split

warnings.filterwarnings("ignore")

# TensorFlow가 있으면 그걸로, 없으면 가벼운 ai-edge-litert 로 실행
try:
    import tensorflow as tf
    Interpreter = tf.lite.Interpreter
except ImportError:
    from ai_edge_litert.interpreter import Interpreter

LABELS = ["정자세", "깊이 부족", "상체 숙임", "무릎 과다 전진", "뒤꿈치 들림", "좌우 비대칭"]  # 0~5 (추정, 확인 필요)
DATA = "squat_features_augmented.csv"
MODEL = "squat_model.tflite"
SCALER = "scaler.pkl"


def predict(X):
    """12개 특징값 → 6개 자세 확률 (앱과 같은 계산: 표준화 → 모델)"""
    scaler = pickle.load(open(SCALER, "rb"))
    it = Interpreter(model_path=MODEL)
    inp = it.get_input_details()[0]
    out = it.get_output_details()[0]
    it.resize_tensor_input(inp["index"], [len(X), X.shape[1]])
    it.allocate_tensors()
    it.set_tensor(inp["index"], scaler.transform(X).astype(np.float32))
    it.invoke()
    return it.get_tensor(out["index"])


def main():
    df = pd.read_csv(DATA)
    X = df.drop(columns=["video_file", "frame", "label"])
    y = df["label"].to_numpy()

    probs = predict(X)
    pred = probs.argmax(1)
    correct = pred == y

    # train_repeat.py 와 같은 분할 (10%, random_state=42)
    _, test_idx = train_test_split(np.arange(len(df)), test_size=0.1, random_state=42, stratify=y)

    print(f"데이터: {len(df):,}개 (영상 {df['video_file'].nunique()}개 × 라벨 {len(np.unique(y))}종)\n")
    print(f"1) 테스트 데이터 정확도 (10%): {correct[test_idx].mean() * 100:.2f}%")
    print(f"2) 전체 데이터 정확도        : {correct.mean() * 100:.2f}%")

    print("\n3) 자세별 정확도")
    for k in range(len(LABELS)):
        m = y == k
        if m.any():
            print(f"   {k} {LABELS[k]:<8} {correct[m].mean() * 100:6.2f}%  ({m.sum():,}개)")

    print(f"\n4) 평균 예측 확신도: {probs.max(1).mean() * 100:.2f}%")

    print("\n5) 영상별 정확도")
    by_video = pd.Series(correct).groupby(df["video_file"]).mean().sort_values()
    for v, acc in by_video.items():
        print(f"   {v:<10} {acc * 100:6.2f}%")


if __name__ == "__main__":
    main()
