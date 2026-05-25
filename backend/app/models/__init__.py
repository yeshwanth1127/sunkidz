from app.core.database import Base
from app.models.user import User, UserRole
from app.models.branch import Branch, BranchAssignment, Class
from app.models.student import Student, ParentStudentLink
from app.models.enquiry import Enquiry
from app.models.marks_card import MarksCard
from app.models.attendance import Attendance
from app.models.staff_attendance import StaffAttendance
from app.models.bus_route import BusRoute, RouteStudent
from app.models.ride_session import RideSession, LocationUpdate
from app.models.daycare import DaycareGroup, DaycareGroupStudent, DaycareDailyUpdate
from app.models.syllabus import Syllabus, Homework, GalleryImage
from app.models.syllabus_holiday import SyllabusHoliday
from app.models.class_diary import ClassDiaryEntry
from app.models.almanac_event import AlmanacEvent
from app.models.daily_story import DailyStory, DailyStoryBranch, DailyStoryClass
from app.models.fees import FeeStructure, FeePayment
from app.models.message import MessageThread, Message
from app.models.leave import LeaveApplication
# from app.models.learning_module import LearningModule, LearningVideo  # TODO: uncomment after fixing database

__all__ = [
    "Base",
    "User",
    "UserRole",
    "Branch",
    "BranchAssignment",
    "Class",
    "Student",
    "ParentStudentLink",
    "Enquiry",
    "MarksCard",
    "Attendance",
    "StaffAttendance",
    "BusRoute",
    "RouteStudent",
    "RideSession",
    "LocationUpdate",
    "DaycareGroup",
    "DaycareGroupStudent",
    "DaycareDailyUpdate",
    "Syllabus",
    "SyllabusHoliday",
    "ClassDiaryEntry",
    "AlmanacEvent",
    "DailyStory",
    "DailyStoryBranch",
    "DailyStoryClass",
    "Homework",
    "GalleryImage",
    "FeeStructure",
    "FeePayment",
    "MessageThread",
    "Message",
    "LeaveApplication",
    # "LearningModule",  # TODO: uncomment after fixing database
    # "LearningVideo",   # TODO: uncomment after fixing database
]
