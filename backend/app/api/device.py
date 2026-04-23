from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session
from app.core.database import get_db
from app.core.auth import get_current_user
from app.models.user import User
from app.schemas.device import DeviceRegisterRequest, DeviceRegisterResponse

router = APIRouter(prefix="/device", tags=["device"])


@router.post("/register", response_model=DeviceRegisterResponse)
def register_device(
    data: DeviceRegisterRequest,
    user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    """Register OneSignal subscription ID for the authenticated user."""
    db_user = db.query(User).filter(User.id == user.id).first()
    if not db_user:
        return DeviceRegisterResponse(success=False, message="User not found")
    db_user.onesignal_player_id = data.onesignal_player_id
    db.commit()
    return DeviceRegisterResponse(success=True, message="Device registered")
