"""
Aiproject의 squat_model.tflite + scaler.pkl 을 Flutter용 Dart 파일로 변환합니다.

사용법 (Aiproject 폴더에서):
    pip install ai-edge-litert scikit-learn numpy
    python export_squat_model.py ../flutter_application_1/lib/ai/squat_model_data.dart

모델 구조가 Dense 4층(12→128→64→32→6)일 때만 동작합니다.
"""
import pickle
import sys
import warnings

import numpy as np
from ai_edge_litert.interpreter import Interpreter

warnings.filterwarnings("ignore")
out_path = sys.argv[1] if len(sys.argv) > 1 else "squat_model_data.dart"

it = Interpreter(model_path="squat_model.tflite")
it.allocate_tensors()

# 상수 텐서 중 2차원 = 가중치, 1차원 = 편향. 입력 크기 순서대로 이어 붙임
details = it.get_tensor_details()
weights = [d for d in details if len(d["shape"]) == 2 and d["shape"][0] > 1 and "MatMul" in d["name"] and ";" not in d["name"]]
biases = [d for d in details if len(d["shape"]) == 1]
layers = []
in_dim = 12
for _ in range(4):
    w = next(d for d in weights if d["shape"][1] == in_dim)
    out_dim = w["shape"][0]
    b = next(d for d in biases if d["shape"][0] == out_dim)
    layers.append((np.array(it.get_tensor(w["index"])), np.array(it.get_tensor(b["index"]))))
    in_dim = out_dim

scaler = pickle.load(open("scaler.pkl", "rb"))


def num(v):
    s = np.format_float_positional(np.float32(v), unique=True, trim="0")
    return s if "." in s else s + ".0"


def lst(v):
    return "[" + ", ".join(num(x) for x in v) + "]"


lines = [
    "// 자동 생성 파일 - 직접 수정하지 마세요.",
    "// 출처: Aiproject/squat_model.tflite (12 → 128 → 64 → 32 → 6 신경망)와 scaler.pkl (StandardScaler)",
    "// TFLite 런타임 없이 Dart로 같은 계산을 하기 위해 가중치를 그대로 옮겨 둔 것입니다.",
    "// 모델을 다시 학습하면 tools/export_squat_model.py 로 이 파일을 다시 만드세요.",
    "",
    "const List<String> kSquatFeatureNames = [" + ", ".join(f"'{n}'" for n in scaler.feature_names_in_) + "];",
    "",
    "const List<double> kScalerMean = " + lst(scaler.mean_) + ";",
    "const List<double> kScalerScale = " + lst(scaler.scale_) + ";",
    "",
    "/// [층][출력 뉴런][입력]",
    "const List<List<List<double>>> kLayerWeights = [",
    *["  [" + ", ".join(lst(r) for r in w) + "]," for w, _ in layers],
    "];",
    "",
    "const List<List<double>> kLayerBiases = [",
    *["  " + lst(b) + "," for _, b in layers],
    "];",
    "",
]
open(out_path, "w", encoding="utf-8").write("\n".join(lines))
print(f"저장 완료: {out_path}")
