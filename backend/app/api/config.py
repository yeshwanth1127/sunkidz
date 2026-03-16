from fastapi import APIRouter
from app.core.config import settings

router = APIRouter(prefix="/config", tags=["config"])

@router.get("/onesignal-app-id")
def get_onesignal_app_id():
    return {"app_id": settings.onesignal_app_id}
