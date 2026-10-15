from typing import Generic, Literal, TypeVar
from pydantic import BaseModel, ConfigDict, Field, model_validator

PROTOCOL_VERSION="1.0" #규약 버전

LANDMARK_COUNT={"pose":33, "hand": 21} #미디어 파이프 점 갯수
class StrictModel(BaseModel):
    model_config = ConfigDict(
        extra="forbid",
        strict=True,
        allow_inf_nan=False,
    )

class Landmark(StrictModel): #x,y 왼쪽 z는 깊이
    x: float = Field(..., ge=-1.0, le=2.0)
    y: float = Field(..., ge=-1.0, le=2.0)
    z: float = Field(..., ge=-10.0, le=10.0)
    visibility: float | None = Field(default=None, ge=0.0, le=1.0)
class WorldLandmark(StrictModel): #엉덩이 기준 위 아래 높이 5m
    world_x: float = Field(..., ge=-5.0, le=5.0)
    world_y: float = Field(..., ge=-5.0, le=5.0)
    world_z: float = Field(..., ge=-5.0, le=5.0)
    visibility: float | None = Field(default=None, ge=0.0, le=1.0)

class Landmarks(StrictModel): #JSON으로 들어오는 데이터 구조
    protocol_version: Literal["1.0"] = PROTOCOL_VERSION
    model: Literal["pose", "hand"] #포즈 핸드 제외 거부
    frame_id:int =Field(...,ge=0, description="프레임 번호 (0부터 증가)")
    timestamp: int = Field(..., ge=0, description="촬영 시각, 밀리초")
    landmarks: list[Landmark]
    world_landmarks: list[WorldLandmark] | None = None

    @model_validator(mode="after")
    def check_landmark_count(self):
        expected = LANDMARK_COUNT[self.model]
        if len(self.landmarks) != expected:
            raise ValueError(
                f"{self.model} 모델은 landmarks {expected}개가 필요한데 {len(self.landmaks)}개가 왔습니다"
            )
        if self.world_landmarks is not None and len(self.world_landmarks) != expected:
            raise ValueError(
                f"{self.model} 모델은 world_landmarks {expected}개가 필요한데 {len(self.world_landmarks)}개가 왔습니다"
            )
        return self

class LandmarkAck(BaseModel): #성공
    frame_id:int
    model:Literal["pose","hand"]
    received:int
    has_world_landmarks:bool

T = TypeVar("T")

class SuccessResponse(BaseModel, Generic[T]): #성공 표시
    status : Literal["ok"] = "ok"
    protocol_version: str = PROTOCOL_VERSION
    data : T

ErrorCode = Literal[ #오류
    "VALIDATION_ERROR",
    "MALFORMED_JSON",
    "NOT_FOUND",
    "METHOD_NOT_ALLOWED",
    "INTERNAL_ERROR",
]

class ErrorDetail(BaseModel):
    loc : list[str|int] = Field(...,description='오류 위치. 예: ["landmarks", 25, "x"]')
    msg : str
    type : str

class ErrorBody(BaseModel):
    code : ErrorCode
    message : str
    details : list[ErrorDetail] = []

class ErrorResponce(BaseModel):
    status : Literal["error"] = "error"
    protocol_version : str = PROTOCOL_VERSION
    error : ErrorBody