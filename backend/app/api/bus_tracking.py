from uuid import UUID
from datetime import datetime, timezone
from typing import Optional
from fastapi import APIRouter, Depends, HTTPException, Query
from sqlalchemy.orm import Session
from sqlalchemy import and_, desc

from app.core.database import get_db
from app.core.auth import get_current_user, require_admin
from app.core.security import get_password_hash
from app.models import User, BusRoute, RouteStudent, RideSession, LocationUpdate, Student, Branch
from app.schemas.bus_tracking import (
    BusRouteCreate,
    BusRouteUpdate,
    BusRouteResponse,
    RouteStudentResponse,
    RouteStudentCreate,
    LocationUpdateCreate,
    LocationUpdateResponse,
    RideSessionCreate,
    RideSessionResponse,
    RideHistoryResponse,
)

router = APIRouter(prefix="/bus-tracking", tags=["bus-tracking"])


# ==================== ADMIN ROUTE MANAGEMENT ====================

@router.post("/admin/routes", response_model=BusRouteResponse)
def create_route(
    data: BusRouteCreate,
    db: Session = Depends(get_db),
    _: User = Depends(require_admin),
):
    """Create a new bus route."""
    route = BusRoute(
        name=data.name,
        description=data.description,
        shift=data.shift,
        branch_id=UUID(data.branch_id),
        bus_staff_id=UUID(data.bus_staff_id),
    )
    db.add(route)
    db.commit()
    db.refresh(route)
    
    bus_staff = db.query(User).filter(User.id == route.bus_staff_id).first()
    return BusRouteResponse(
        id=str(route.id),
        name=route.name,
        description=route.description,
        shift=route.shift,
        branch_id=str(route.branch_id),
        bus_staff_id=str(route.bus_staff_id),
        bus_staff_name=bus_staff.full_name if bus_staff else None,
        is_active=route.is_active,
        students=[],
        created_at=route.created_at.isoformat(),
    )


@router.get("/admin/routes", response_model=list[BusRouteResponse])
def list_routes(
    branch_id: Optional[str] = Query(None),
    shift: Optional[str] = Query(None),
    db: Session = Depends(get_db),
    _: User = Depends(require_admin),
):
    """List all bus routes with optional filtering."""
    q = db.query(BusRoute)
    if branch_id:
        q = q.filter(BusRoute.branch_id == UUID(branch_id))
    if shift:
        q = q.filter(BusRoute.shift == shift)
    
    routes = q.all()
    result = []
    for route in routes:
        bus_staff = db.query(User).filter(User.id == route.bus_staff_id).first()
        students = []
        for rs in route.students:
            s = rs.student
            students.append(RouteStudentResponse(
                id=str(rs.id),
                student_id=str(rs.student_id),
                student_name=s.name if s else "Unknown",
                pickup_order=rs.pickup_order,
                pickup_address=rs.pickup_address,
                pickup_time=rs.pickup_time,
            ))
        result.append(BusRouteResponse(
            id=str(route.id),
            name=route.name,
            description=route.description,
            shift=route.shift,
            branch_id=str(route.branch_id),
            bus_staff_id=str(route.bus_staff_id),
            bus_staff_name=bus_staff.full_name if bus_staff else None,
            is_active=route.is_active,
            students=students,
            created_at=route.created_at.isoformat(),
        ))
    return result


@router.get("/admin/routes/{route_id}", response_model=BusRouteResponse)
def get_route(
    route_id: UUID,
    db: Session = Depends(get_db),
    _: User = Depends(require_admin),
):
    """Get a specific route."""
    route = db.query(BusRoute).filter(BusRoute.id == route_id).first()
    if not route:
        raise HTTPException(status_code=404, detail="Route not found")
    
    bus_staff = db.query(User).filter(User.id == route.bus_staff_id).first()
    students = []
    for rs in route.students:
        s = rs.student
        students.append(RouteStudentResponse(
            id=str(rs.id),
            student_id=str(rs.student_id),
            student_name=s.name if s else "Unknown",
            pickup_order=rs.pickup_order,
            pickup_address=rs.pickup_address,
            pickup_time=rs.pickup_time,
        ))
    
    return BusRouteResponse(
        id=str(route.id),
        name=route.name,
        description=route.description,
        shift=route.shift,
        branch_id=str(route.branch_id),
        bus_staff_id=str(route.bus_staff_id),
        bus_staff_name=bus_staff.full_name if bus_staff else None,
        is_active=route.is_active,
        students=students,
        created_at=route.created_at.isoformat(),
    )


@router.put("/admin/routes/{route_id}", response_model=BusRouteResponse)
def update_route(
    route_id: UUID,
    data: BusRouteUpdate,
    db: Session = Depends(get_db),
    _: User = Depends(require_admin),
):
    """Update a route."""
    route = db.query(BusRoute).filter(BusRoute.id == route_id).first()
    if not route:
        raise HTTPException(status_code=404, detail="Route not found")
    
    if data.name is not None:
        route.name = data.name
    if data.description is not None:
        route.description = data.description
    if data.is_active is not None:
        route.is_active = data.is_active
    
    db.commit()
    db.refresh(route)
    
    bus_staff = db.query(User).filter(User.id == route.bus_staff_id).first()
    students = []
    for rs in route.students:
        s = rs.student
        students.append(RouteStudentResponse(
            id=str(rs.id),
            student_id=str(rs.student_id),
            student_name=s.name if s else "Unknown",
            pickup_order=rs.pickup_order,
            pickup_address=rs.pickup_address,
            pickup_time=rs.pickup_time,
        ))
    
    return BusRouteResponse(
        id=str(route.id),
        name=route.name,
        description=route.description,
        shift=route.shift,
        branch_id=str(route.branch_id),
        bus_staff_id=str(route.bus_staff_id),
        bus_staff_name=bus_staff.full_name if bus_staff else None,
        is_active=route.is_active,
        students=students,
        created_at=route.created_at.isoformat(),
    )


@router.delete("/admin/routes/{route_id}")
def delete_route(
    route_id: UUID,
    db: Session = Depends(get_db),
    _: User = Depends(require_admin),
):
    """Delete a route."""
    route = db.query(BusRoute).filter(BusRoute.id == route_id).first()
    if not route:
        raise HTTPException(status_code=404, detail="Route not found")
    
    db.delete(route)
    db.commit()
    return {"ok": True}


@router.post("/admin/routes/{route_id}/students")
def add_students_to_route(
    route_id: UUID,
    students: list[RouteStudentCreate],
    db: Session = Depends(get_db),
    _: User = Depends(require_admin),
):
    """Add students to a route."""
    route = db.query(BusRoute).filter(BusRoute.id == route_id).first()
    if not route:
        raise HTTPException(status_code=404, detail="Route not found")
    
    # Delete existing students
    db.query(RouteStudent).filter(RouteStudent.route_id == route_id).delete()
    
    # Add new students
    for student in students:
        s = db.query(Student).filter(Student.id == UUID(student.student_id)).first()
        if not s:
            raise HTTPException(status_code=404, detail=f"Student {student.student_id} not found")
        
        rs = RouteStudent(
            route_id=route_id,
            student_id=UUID(student.student_id),
            pickup_order=student.pickup_order,
            pickup_address=student.pickup_address,
            pickup_time=student.pickup_time,
        )
        db.add(rs)
    
    db.commit()
    return {"ok": True, "count": len(students)}


# ==================== BUS STAFF TRACKING ====================

@router.get("/bus-staff/my-route", response_model=BusRouteResponse)
def get_my_route(
    user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    """Get the route assigned to this bus staff."""
    if user.role != "bus_staff":
        raise HTTPException(status_code=403, detail="Only bus staff can access this")
    
    route = db.query(BusRoute).filter(BusRoute.bus_staff_id == user.id).first()
    if not route:
        raise HTTPException(status_code=404, detail="No route assigned")
    
    students = []
    for rs in route.students:
        s = rs.student
        students.append(RouteStudentResponse(
            id=str(rs.id),
            student_id=str(rs.student_id),
            student_name=s.name if s else "Unknown",
            pickup_order=rs.pickup_order,
            pickup_address=rs.pickup_address,
            pickup_time=rs.pickup_time,
        ))
    
    return BusRouteResponse(
        id=str(route.id),
        name=route.name,
        description=route.description,
        shift=route.shift,
        branch_id=str(route.branch_id),
        bus_staff_id=str(route.bus_staff_id),
        bus_staff_name=user.full_name,
        is_active=route.is_active,
        students=sorted(students, key=lambda x: x.pickup_order),
        created_at=route.created_at.isoformat(),
    )


@router.post("/bus-staff/rides/start", response_model=RideSessionResponse)
def start_ride(
    user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    """Start a new ride session."""
    if user.role != "bus_staff":
        raise HTTPException(status_code=403, detail="Only bus staff can start rides")
    
    # Automatically get the route assigned to this user
    route = db.query(BusRoute).filter(BusRoute.bus_staff_id == user.id).first()
    if not route:
        raise HTTPException(status_code=404, detail="No route assigned to you")
    
    # Check if there's already an active ride
    active = db.query(RideSession).filter(
        and_(
            RideSession.bus_staff_id == user.id,
            RideSession.status == "active"
        )
    ).first()
    
    if active:
        raise HTTPException(status_code=400, detail="You already have an active ride")
    
    ride = RideSession(
        route_id=route.id,
        bus_staff_id=user.id,
        start_time=datetime.now(timezone.utc),
        status="active",
    )
    db.add(ride)
    db.commit()
    db.refresh(ride)
    
    return RideSessionResponse(
        id=str(ride.id),
        route_id=str(ride.route_id),
        bus_staff_id=str(ride.bus_staff_id),
        route_name=route.name,
        bus_staff_name=user.full_name,
        start_time=ride.start_time.isoformat(),
        end_time=None,
        status=ride.status,
        total_distance_km=ride.total_distance_km,
        latest_location=None,
        created_at=ride.created_at.isoformat(),
    )


@router.post("/bus-staff/rides/{ride_id}/update-location", response_model=LocationUpdateResponse)
def update_location(
    ride_id: UUID,
    data: LocationUpdateCreate,
    user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    """Update the live location for an active ride."""
    if user.role != "bus_staff":
        raise HTTPException(status_code=403, detail="Only bus staff can update locations")
    
    ride = db.query(RideSession).filter(RideSession.id == ride_id).first()
    if not ride:
        raise HTTPException(status_code=404, detail="Ride not found")
    
    if ride.bus_staff_id != user.id:
        raise HTTPException(status_code=403, detail="This ride is not yours")
    
    if ride.status != "active":
        raise HTTPException(status_code=400, detail="Ride is not active")
    
    location = LocationUpdate(
        ride_session_id=ride_id,
        latitude=data.latitude,
        longitude=data.longitude,
        accuracy=data.accuracy,
        speed=data.speed,
        heading=data.heading,
        altitude=data.altitude,
        timestamp=datetime.now(timezone.utc),
    )
    db.add(location)
    db.commit()
    db.refresh(location)
    
    return LocationUpdateResponse(
        id=str(location.id),
        latitude=location.latitude,
        longitude=location.longitude,
        accuracy=location.accuracy,
        speed=location.speed,
        heading=location.heading,
        altitude=location.altitude,
        timestamp=location.timestamp.isoformat(),
        created_at=location.created_at.isoformat(),
    )


@router.post("/bus-staff/rides/{ride_id}/end", response_model=RideSessionResponse)
def end_ride(
    ride_id: UUID,
    user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    """End an active ride session."""
    if user.role != "bus_staff":
        raise HTTPException(status_code=403, detail="Only bus staff can end rides")
    
    ride = db.query(RideSession).filter(RideSession.id == ride_id).first()
    if not ride:
        raise HTTPException(status_code=404, detail="Ride not found")
    
    if ride.bus_staff_id != user.id:
        raise HTTPException(status_code=403, detail="This ride is not yours")
    
    if ride.status != "active":
        raise HTTPException(status_code=400, detail="Ride is not active")
    
    ride.end_time = datetime.now(timezone.utc)
    ride.status = "completed"
    
    # Calculate distance (simple implementation - can be improved)
    locations = db.query(LocationUpdate).filter(
        LocationUpdate.ride_session_id == ride_id
    ).order_by(LocationUpdate.timestamp).all()
    
    if locations:
        # TODO: Implement proper distance calculation using haversine formula
        ride.total_distance_km = 0.0
    
    db.commit()
    db.refresh(ride)
    
    route = db.query(BusRoute).filter(BusRoute.id == ride.route_id).first()
    return RideSessionResponse(
        id=str(ride.id),
        route_id=str(ride.route_id),
        bus_staff_id=str(ride.bus_staff_id),
        route_name=route.name if route else None,
        bus_staff_name=user.full_name,
        start_time=ride.start_time.isoformat(),
        end_time=ride.end_time.isoformat() if ride.end_time else None,
        status=ride.status,
        total_distance_km=ride.total_distance_km,
        latest_location=None,
        created_at=ride.created_at.isoformat(),
    )


@router.get("/bus-staff/rides/active", response_model=Optional[RideSessionResponse])
def get_active_ride(
    user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    """Get the current active ride for this bus staff."""
    if user.role != "bus_staff":
        raise HTTPException(status_code=403, detail="Only bus staff can access this")
    
    ride = db.query(RideSession).filter(
        and_(
            RideSession.bus_staff_id == user.id,
            RideSession.status == "active"
        )
    ).first()
    
    if not ride:
        return None
    
    route = db.query(BusRoute).filter(BusRoute.id == ride.route_id).first()
    latest_loc = db.query(LocationUpdate).filter(
        LocationUpdate.ride_session_id == ride.id
    ).order_by(desc(LocationUpdate.timestamp)).first()
    
    latest_location_response = None
    if latest_loc:
        latest_location_response = LocationUpdateResponse(
            id=str(latest_loc.id),
            latitude=latest_loc.latitude,
            longitude=latest_loc.longitude,
            accuracy=latest_loc.accuracy,
            speed=latest_loc.speed,
            heading=latest_loc.heading,
            altitude=latest_loc.altitude,
            timestamp=latest_loc.timestamp.isoformat(),
            created_at=latest_loc.created_at.isoformat(),
        )
    
    return RideSessionResponse(
        id=str(ride.id),
        route_id=str(ride.route_id),
        bus_staff_id=str(ride.bus_staff_id),
        route_name=route.name if route else None,
        bus_staff_name=user.full_name,
        start_time=ride.start_time.isoformat(),
        end_time=ride.end_time.isoformat() if ride.end_time else None,
        status=ride.status,
        total_distance_km=ride.total_distance_km,
        latest_location=latest_location_response,
        created_at=ride.created_at.isoformat(),
    )


# ==================== ADMIN TRACKING ====================

@router.get("/admin/rides/active", response_model=list[RideSessionResponse])
def get_all_active_rides(
    branch_id: Optional[str] = Query(None),
    db: Session = Depends(get_db),
    _: User = Depends(require_admin),
):
    """Get all active rides across the system."""
    q = db.query(RideSession).filter(RideSession.status == "active")
    
    if branch_id:
        q = q.join(BusRoute).filter(BusRoute.branch_id == UUID(branch_id))
    
    rides = q.all()
    result = []
    
    for ride in rides:
        route = db.query(BusRoute).filter(BusRoute.id == ride.route_id).first()
        bus_staff = db.query(User).filter(User.id == ride.bus_staff_id).first()
        latest_loc = db.query(LocationUpdate).filter(
            LocationUpdate.ride_session_id == ride.id
        ).order_by(desc(LocationUpdate.timestamp)).first()
        
        latest_location_response = None
        if latest_loc:
            latest_location_response = LocationUpdateResponse(
                id=str(latest_loc.id),
                latitude=latest_loc.latitude,
                longitude=latest_loc.longitude,
                accuracy=latest_loc.accuracy,
                speed=latest_loc.speed,
                heading=latest_loc.heading,
                altitude=latest_loc.altitude,
                timestamp=latest_loc.timestamp.isoformat(),
                created_at=latest_loc.created_at.isoformat(),
            )
        
        result.append(RideSessionResponse(
            id=str(ride.id),
            route_id=str(ride.route_id),
            bus_staff_id=str(ride.bus_staff_id),
            route_name=route.name if route else None,
            bus_staff_name=bus_staff.full_name if bus_staff else None,
            start_time=ride.start_time.isoformat(),
            end_time=ride.end_time.isoformat() if ride.end_time else None,
            status=ride.status,
            total_distance_km=ride.total_distance_km,
            latest_location=latest_location_response,
            created_at=ride.created_at.isoformat(),
        ))
    
    return result


@router.get("/admin/rides/{ride_id}/locations", response_model=list[LocationUpdateResponse])
def get_ride_locations(
    ride_id: UUID,
    limit: int = Query(100, le=1000),
    db: Session = Depends(get_db),
    _: User = Depends(require_admin),
):
    """Get all location updates for a specific ride."""
    ride = db.query(RideSession).filter(RideSession.id == ride_id).first()
    if not ride:
        raise HTTPException(status_code=404, detail="Ride not found")
    
    locations = db.query(LocationUpdate).filter(
        LocationUpdate.ride_session_id == ride_id
    ).order_by(LocationUpdate.timestamp).limit(limit).all()
    
    return [
        LocationUpdateResponse(
            id=str(loc.id),
            latitude=loc.latitude,
            longitude=loc.longitude,
            accuracy=loc.accuracy,
            speed=loc.speed,
            heading=loc.heading,
            altitude=loc.altitude,
            timestamp=loc.timestamp.isoformat(),
            created_at=loc.created_at.isoformat(),
        )
        for loc in locations
    ]


@router.get("/admin/rides/history", response_model=list[RideHistoryResponse])
def get_ride_history(
    branch_id: Optional[str] = Query(None),
    bus_staff_id: Optional[str] = Query(None),
    limit: int = Query(50, le=500),
    db: Session = Depends(get_db),
    _: User = Depends(require_admin),
):
    """Get historical rides."""
    q = db.query(RideSession).filter(RideSession.status.in_(["completed", "cancelled"]))
    
    if branch_id:
        q = q.join(BusRoute).filter(BusRoute.branch_id == UUID(branch_id))
    
    if bus_staff_id:
        q = q.filter(RideSession.bus_staff_id == UUID(bus_staff_id))
    
    rides = q.order_by(desc(RideSession.start_time)).limit(limit).all()
    result = []
    
    for ride in rides:
        route = db.query(BusRoute).filter(BusRoute.id == ride.route_id).first()
        bus_staff = db.query(User).filter(User.id == ride.bus_staff_id).first()
        student_count = db.query(RouteStudent).filter(RouteStudent.route_id == ride.route_id).count()
        
        duration = 0
        if ride.end_time:
            duration = int((ride.end_time - ride.start_time).total_seconds() / 60)
        
        result.append(RideHistoryResponse(
            id=str(ride.id),
            route_id=str(ride.route_id),
            route_name=route.name if route else "Unknown",
            bus_staff_name=bus_staff.full_name if bus_staff else "Unknown",
            shift=route.shift if route else "Unknown",
            start_time=ride.start_time.isoformat(),
            end_time=ride.end_time.isoformat() if ride.end_time else None,
            duration_minutes=duration,
            total_distance_km=ride.total_distance_km or 0.0,
            student_count=student_count,
            status=ride.status,
        ))
    
    return result


# ==================== PARENT TRACKING ====================

@router.get("/parent/my-children-rides", response_model=list[RideSessionResponse])
def get_my_children_rides(
    user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    """Get active rides for my children."""
    if user.role != "parent":
        raise HTTPException(status_code=403, detail="Only parents can access this")
    
    from app.models.student import ParentStudentLink
    
    # Get all students linked to this parent who have opted for bus service
    links = db.query(ParentStudentLink).filter(ParentStudentLink.user_id == user.id).all()
    student_ids = [l.student_id for l in links]
    
    if not student_ids:
        return []
    
    # Filter to only students who have opted for bus service
    opted_students = db.query(Student).filter(
        and_(
            Student.id.in_(student_ids),
            Student.bus_opted == True
        )
    ).all()
    
    if not opted_students:
        return []
    
    # Get ALL active rides (parent can see any active ride if they have opted in)
    rides = db.query(RideSession).filter(
        RideSession.status == "active"
    ).all()

    result = []
    for ride in rides:
        route = db.query(BusRoute).filter(BusRoute.id == ride.route_id).first()
        bus_staff = db.query(User).filter(User.id == ride.bus_staff_id).first()
        latest_loc = db.query(LocationUpdate).filter(
            LocationUpdate.ride_session_id == ride.id
        ).order_by(desc(LocationUpdate.timestamp)).first()
        
        latest_location_response = None
        if latest_loc:
            latest_location_response = LocationUpdateResponse(
                id=str(latest_loc.id),
                latitude=latest_loc.latitude,
                longitude=latest_loc.longitude,
                accuracy=latest_loc.accuracy,
                speed=latest_loc.speed,
                heading=latest_loc.heading,
                altitude=latest_loc.altitude,
                timestamp=latest_loc.timestamp.isoformat(),
                created_at=latest_loc.created_at.isoformat(),
            )
        
        result.append(RideSessionResponse(
            id=str(ride.id),
            route_id=str(ride.route_id),
            bus_staff_id=str(ride.bus_staff_id),
            route_name=route.name if route else None,
            bus_staff_name=bus_staff.full_name if bus_staff else None,
            start_time=ride.start_time.isoformat(),
            end_time=ride.end_time.isoformat() if ride.end_time else None,
            status=ride.status,
            total_distance_km=ride.total_distance_km,
            latest_location=latest_location_response,
            created_at=ride.created_at.isoformat(),
        ))
    
    return result

    result = []
    for ride in rides:
        route = db.query(BusRoute).filter(BusRoute.id == ride.route_id).first()
        bus_staff = db.query(User).filter(User.id == ride.bus_staff_id).first()
        latest_loc = db.query(LocationUpdate).filter(
            LocationUpdate.ride_session_id == ride.id
        ).order_by(desc(LocationUpdate.timestamp)).first()
        
        latest_location_response = None
        if latest_loc:
            latest_location_response = LocationUpdateResponse(
                id=str(latest_loc.id),
                latitude=latest_loc.latitude,
                longitude=latest_loc.longitude,
                accuracy=latest_loc.accuracy,
                speed=latest_loc.speed,
                heading=latest_loc.heading,
                altitude=latest_loc.altitude,
                timestamp=latest_loc.timestamp.isoformat(),
                created_at=latest_loc.created_at.isoformat(),
            )
        
        result.append(RideSessionResponse(
            id=str(ride.id),
            route_id=str(ride.route_id),
            bus_staff_id=str(ride.bus_staff_id),
            route_name=route.name if route else None,
            bus_staff_name=bus_staff.full_name if bus_staff else None,
            start_time=ride.start_time.isoformat(),
            end_time=ride.end_time.isoformat() if ride.end_time else None,
            status=ride.status,
            total_distance_km=ride.total_distance_km,
            latest_location=latest_location_response,
            created_at=ride.created_at.isoformat(),
        ))
    
    return result
