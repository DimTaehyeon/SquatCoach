from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from errors import register_exception_handlers
from schemas import (
    PROTOCOL_VERSION, ErrorResponse, LandmarkACK, LandmarkFrame, SuccessResponse,
)

app=FastAPI(
    title="Squat Coach Server",
    version=PROTOCOL_VERSION,
    description="MediaPipe 랜드마크를 받아 검사하는 로컬 백엔드",
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=["http://localhost:5173", "http://localhost:3000",
    "http://127.0.0.1:5173", "http://127.0.0.1:3000"],
    allow_methods=["GET","POST"],
    allow_headers=["Comtent-Type"],
)

register_exception_handlers(app)

ERROR_RESPONSES = {
    400 : {"model":ErrorResponse, "description":"JSON파싱 실패"},
    422 : {"model":ErrorResponse, "description":"스키마/값 검사 실패"},
    500 : {"model":ErrorResponse, "description":"서버 내부 오류"},
}

@app.get("/health")
def health():
    return{"status": "ok", "protocol_version": PROTOCOL_VERSION}

@app.post(
    "/api/v1/landmarks",
    response_model=SuccessResponse[LandmarkACK],
    reponses=ERROR_RESPONSES,
    summary="MediaPipe 랜드마크 한 프레임 수신",
)
def receive_landmarks(frame: LandmarkFrame):
    ack = LandmarkACK(
        frame_id=frame.frame_id,
        model=frame.model,
        received=len(frame.landmarks),
        has_world_landmarks=frame.world_landmarks is not None,
    )
    return SuccessResponse(data=ack)