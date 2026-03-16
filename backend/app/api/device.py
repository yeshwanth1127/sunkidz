from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session
from app.core.database import get_db
from app.models.user import User
from app.schemas.device import DeviceRegisterRequest, DeviceRegisterResponse

router = APIRouter(prefix="/device", tags=["device"])

@router.post("/register", response_model=DeviceRegisterResponse)
def register_device(data: DeviceRegisterRequest, db: Session = Depends(get_db)):
    user = db.query(User).filter(User.id == data.user_id).first()
    if not user:
        return DeviceRegisterResponse(success=False, message="User not found")
    user.onesignal_player_id = data.onesignal_player_id
    db.commit()
    return DeviceRegisterResponse(success=True, message="Player ID registered")
