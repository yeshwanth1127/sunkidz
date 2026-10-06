"""Shared upload validation for homework, chat, etc."""
import os
import uuid
from typing import Optional

from fastapi import HTTPException, UploadFile

# Extensions allowed for homework and chat attachments
STORY_EXTENSIONS = {
    ".jpg", ".jpeg", ".png", ".gif", ".webp",
    ".mp4", ".mov", ".webm", ".mkv", ".3gp",
}

ALLOWED_EXTENSIONS = {
    ".pdf",
    ".jpg", ".jpeg", ".png", ".gif", ".webp",
    ".mp4", ".mov", ".webm", ".mkv", ".3gp",
    ".doc", ".docx",
}

IMAGE_EXTENSIONS = {".jpg", ".jpeg", ".png", ".gif", ".webp"}
VIDEO_EXTENSIONS = {".mp4", ".mov", ".webm", ".mkv", ".3gp"}
PDF_EXTENSIONS = {".pdf"}

MAX_UPLOAD_BYTES = 1500 * 1024 * 1024  # 1500 MB
MIN_VIDEO_BYTES = 60 * 1024  # 60 KB - reject tiny placeholder videos

MIME_BY_EXT = {
    ".pdf": "application/pdf",
    ".jpg": "image/jpeg",
    ".jpeg": "image/jpeg",
    ".png": "image/png",
    ".gif": "image/gif",
    ".webp": "image/webp",
    ".mp4": "video/mp4",
    ".mov": "video/quicktime",
    ".webm": "video/webm",
    ".mkv": "video/x-matroska",
    ".3gp": "video/3gpp",
    ".doc": "application/msword",
    ".docx": "application/vnd.openxmlformats-officedocument.wordprocessingml.document",
}


def media_kind_for_filename(filename: str) -> str:
    ext = os.path.splitext((filename or "").lower())[1]
    if ext in IMAGE_EXTENSIONS:
        return "image"
    if ext in VIDEO_EXTENSIONS:
        return "video"
    if ext in PDF_EXTENSIONS:
        return "pdf"
    return "document"


def mime_for_filename(filename: str) -> str:
    ext = os.path.splitext((filename or "").lower())[1]
    return MIME_BY_EXT.get(ext, "application/octet-stream")


def _looks_like_mp4(content: bytes) -> bool:
    # MP4/QuickTime/3GP typically contain an 'ftyp' box near the start
    head = content[:512]
    return b"ftyp" in head


def _looks_like_webm_mkv(content: bytes) -> bool:
    # WebM/MKV (Matroska) start with EBML header 0x1A45DFA3
    head = content[:4]
    return head == b"\x1A\x45\xDF\xA3"


def validate_video_content(filename: str, content: bytes) -> None:
    """Basic content-signature validation for uploaded video files.

    This is intentionally lightweight: it checks common container signatures
    (MP4 family and EBML for WebM/MKV) and enforces a minimum size to
    reject trivial placeholder files.
    """
    ext = os.path.splitext((filename or "").lower())[1]
    if ext not in VIDEO_EXTENSIONS:
        return
    if len(content) < MIN_VIDEO_BYTES:
        raise HTTPException(status_code=400, detail="Video file too small or invalid")
    # check common signatures
    if _looks_like_mp4(content):
        return
    if _looks_like_webm_mkv(content):
        return
    # Unknown/unsupported container
    raise HTTPException(status_code=400, detail="Uploaded video file appears invalid")


def validate_story_file(file: UploadFile) -> None:
    if not file or not file.filename:
        raise HTTPException(status_code=400, detail="File is required")
    ext = os.path.splitext(file.filename.lower())[1]
    if ext not in STORY_EXTENSIONS:
        raise HTTPException(
            status_code=400,
            detail="Stories support images (jpg, png) or videos (mp4, mov, webm)",
        )


def validate_upload_file(file: UploadFile) -> None:
    if not file or not file.filename:
        raise HTTPException(status_code=400, detail="File is required")
    ext = os.path.splitext(file.filename.lower())[1]
    if ext not in ALLOWED_EXTENSIONS:
        raise HTTPException(
            status_code=400,
            detail="Allowed: images (jpg, png), PDF, Word, videos (mp4, mov, webm)",
        )


async def read_and_validate_size(file: UploadFile) -> bytes:
    content = await file.read()
    if len(content) > MAX_UPLOAD_BYTES:
        raise HTTPException(
            status_code=400,
            detail=f"File too large (max {MAX_UPLOAD_BYTES // (1024 * 1024)} MB)",
        )
    if len(content) == 0:
        raise HTTPException(status_code=400, detail="Empty file")
    return content


async def save_story_file(file: UploadFile, directory: str) -> tuple[str, str, str, str]:
    """Save story media (image or video). Returns (path, name, size_label, mime)."""
    validate_story_file(file)
    content = await read_and_validate_size(file)
    # Validate video content to avoid placeholder non-video files
    validate_video_content(file.filename, content)
    os.makedirs(directory, exist_ok=True)
    ext = os.path.splitext(file.filename)[1].lower()
    unique_name = f"{uuid.uuid4()}{ext}"
    path = os.path.join(directory, unique_name)
    with open(path, "wb") as buffer:
        buffer.write(content)
    size_label = f"{len(content) / 1024:.2f} KB"
    if len(content) >= 1024 * 1024:
        size_label = f"{len(content) / (1024 * 1024):.2f} MB"
    mime = file.content_type if file.content_type and "/" in file.content_type else mime_for_filename(file.filename)
    return path, file.filename, size_label, mime


async def save_upload_file(file: UploadFile, directory: str) -> tuple[str, str, str, str]:
    """Returns (path, original_name, size_label, mime_type)."""
    validate_upload_file(file)
    content = await read_and_validate_size(file)
    # Validate video content for video file types
    validate_video_content(file.filename, content)
    os.makedirs(directory, exist_ok=True)
    ext = os.path.splitext(file.filename)[1].lower()
    unique_name = f"{uuid.uuid4()}{ext}"
    path = os.path.join(directory, unique_name)
    with open(path, "wb") as buffer:
        buffer.write(content)
    size_label = f"{len(content) / 1024:.2f} KB"
    if len(content) >= 1024 * 1024:
        size_label = f"{len(content) / (1024 * 1024):.2f} MB"
    mime = file.content_type if file.content_type and "/" in file.content_type else mime_for_filename(file.filename)
    return path, file.filename, size_label, mime
