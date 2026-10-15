import logging
from fastapi import FastAPI, Request
from fastapi.exceptions import RequestValidationError
from fastapi.responses import JSONResponse
from starlette.exceptions import HTTPException as StarletteHTTPException

from schemas import ErrorBody, ErrorDetail, ErrorResponse

log = logging.getLogger("squat_server")

HTTP_CODE_MAP = {404: "NOT_FOUND", 405: "METHOD_NOT_ALLOWED", 400: "MALFORMED_JSON"}

def error_response(status: int, code: str, message: str, details=None) -> JSONResponse:
    body = ErrorResponse(error=ErrorBody(code=code, message=message, details=details or []))
    return JSONResponse(status_code=status, content=body.model_dump()) #JSON으로 보내기

def register_exception_handlers(app:FastAPI) -> None:
    @app.exception_handler(RequestValidationError)
    async def handle_validation(_:Request, exc:RequestValidationError):
        errors = exc.errors()

        if any(e["type"] == "json_invalid" for e in errors): #400
            return error_response(400, "MALFORMED_JSON", "요청 본문이 올바른 JSON이 아닙니다.")

        details = []
        for e in errors:
            loc = list(e["loc"])
            if loc and loc[0] == "body":
                loc = loc[1:]
            details.append(ErrorDetail(
                loc=loc,
                msg=e["msg"].removeprefix("Value error,"),
                type=e["type"]
            ))
        return error_response(422, "VALIDATION_ERROR", f"요청 검사 실패: 오류 {len(details)}건", details)

    @app.exception_handler(StarletteHTTPException) #404,405
    async def handle_http(_:Request, exc: StarletteHTTPException):
        code = HTTP_CODE_MAP.get(exc.status_code, "INTERNAL_ERROR")
        return error_response(exc.status_code, code, str(exc.detail))

    @app.exception_handler(Exception)#500
    async def handle_unexpected(_:Request, exc: Exception):
        log.exception("예상치 못한 오류 발생: %s", exc)
        return error_response(500, "INTERNAL_ERROR", "서버 내부 오류")