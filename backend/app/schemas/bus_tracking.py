from pydantic import BaseModel
from typing import Optional
from datetime import datetime


class RouteStudentResponse(BaseModel):
    id: str
    student_id: str
    student_name: str
    pickup_order: int
    pickup_address: Optional[str]
    pickup_time: Optional[str]

    class Config:
        from_attributes = True


class BusRouteCreate(BaseModel):
    name: str
    description: Optional[str] = None
    shift: str  # "morning", "afternoon"
    branch_id: str
    bus_staff_id: str


class BusRouteUpdate(BaseModel):
    name: Optional[str] = None
    description: Optional[str] = None
    is_active: Optional[bool] = None


class BusRouteResponse(BaseModel):
    id: str
    name: str
    description: Optional[str]
    shift: str
    branch_id: str
    bus_staff_id: str
    bus_staff_name: Optional[str]
    is_active: bool
    students: list[RouteStudentResponse] = []
    created_at: str

    class Config:
        from_attributes = True


class RouteStudentCreate(BaseModel):
    student_id: str
    pickup_order: int
    pickup_address: Optional[str] = None
    pickup_time: Optional[str] = None  # HH:MM format


class LocationUpdateCreate(BaseModel):
    latitude: float
    longitude: float
    accuracy: Optional[float] = None
    speed: Optional[float] = None
    heading: Optional[float] = None
    altitude: Optional[float] = None


class LocationUpdateResponse(BaseModel):
    id: str
    latitude: float
    longitude: float
    accuracy: Optional[float]
    speed: Optional[float]
    heading: Optional[float]
    altitude: Optional[float]
    timestamp: str
    created_at: str

    class Config:
        from_attributes = True


class RideSessionCreate(BaseModel):
    pass  # No fields needed, route is auto-detected from user


class RideSessionResponse(BaseModel):
    id: str
    route_id: str
    bus_staff_id: str
    route_name: Optional[str]
    bus_staff_name: Optional[str]
    start_time: str
    end_time: Optional[str]
    status: str
    total_distance_km: Optional[float]
    latest_location: Optional[LocationUpdateResponse] = None
    created_at: str

    class Config:
        from_attributes = True


class RideHistoryResponse(BaseModel):
    id: str
    route_id: str
    route_name: str
    bus_staff_name: str
    shift: str
    start_time: str
    end_time: Optional[str]
    duration_minutes: int
    total_distance_km: Optional[float]
    student_count: int
    status: str

    class Config:
        from_attributes = True
