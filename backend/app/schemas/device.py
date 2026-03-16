from uuid import UUID
from pydantic import BaseModel

class DeviceRegisterRequest(BaseModel):
    user_id: UUID
    onesignal_player_id: str

class DeviceRegisterResponse(BaseModel):
    success: bool
    message: str

