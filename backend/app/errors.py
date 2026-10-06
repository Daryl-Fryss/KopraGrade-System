"""Every error leaves the API as  {"error": "message"}  with a fitting status code."""
import logging

from fastapi import FastAPI, Request
from fastapi.exceptions import RequestValidationError
from fastapi.responses import JSONResponse
from sqlalchemy.exc import SQLAlchemyError
from starlette.exceptions import HTTPException as StarletteHTTPException

logger = logging.getLogger("kopragrade")


def _first_message(errors: list[dict]) -> str:
    if not errors:
        return "The request is not valid."
    err = errors[0]
    loc = [str(p) for p in err.get("loc", ()) if p not in ("body", "query", "path", "form")]
    field = loc[-1] if loc else ""
    kind = err.get("type", "")
    msg = err.get("msg", "")

    if kind == "json_invalid":
        return "Request body is not valid JSON."
    if field == "image":
        return 'Please attach one copra image in the "image" field.'
    if kind == "missing":
        return f'"{field}" is required.' if field else "Request body is required."
    if msg.startswith("Value error, "):
        return msg[len("Value error, "):]
    if err.get("loc") and err["loc"][0] == "path":
        return "The id in the address must be a number."
    if not field:
        return "Request body must be a JSON object."
    return f'The value of "{field}" is not valid.'


def install_error_handlers(app: FastAPI) -> None:
    @app.exception_handler(StarletteHTTPException)
    async def http_error(request: Request, exc: StarletteHTTPException) -> JSONResponse:
        detail = exc.detail if isinstance(exc.detail, str) else "The request could not be completed."
        if exc.status_code == 404 and detail == "Not Found":
            detail = "Route not found."
        return JSONResponse({"error": detail}, status_code=exc.status_code, headers=getattr(exc, "headers", None))

    @app.exception_handler(RequestValidationError)
    async def validation_error(request: Request, exc: RequestValidationError) -> JSONResponse:
        return JSONResponse({"error": _first_message(exc.errors())}, status_code=400)

    # Database or disk problems. Registered for these classes (not for Exception) so the
    # response still passes through the CORS middleware and the browser app can read it.
    @app.exception_handler(SQLAlchemyError)
    @app.exception_handler(OSError)
    async def server_problem(request: Request, exc: Exception) -> JSONResponse:
        logger.error("Server problem on %s %s: %r", request.method, request.url.path, exc)
        return JSONResponse({"error": "Something went wrong on the server."}, status_code=500)

    @app.exception_handler(Exception)
    async def unexpected_error(request: Request, exc: Exception) -> JSONResponse:
        logger.exception("Unexpected error on %s %s", request.method, request.url.path)
        return JSONResponse({"error": "Something went wrong on the server."}, status_code=500)
