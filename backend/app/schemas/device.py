from pydantic import BaseModel


class DeviceRegisterRequest(BaseModel):
    """Subscription ID from OneSignal (or legacy player_id)."""
    onesignal_player_id: str

class DeviceRegisterResponse(BaseModel):
    success: bool
    message: str

