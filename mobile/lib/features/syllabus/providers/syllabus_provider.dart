import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/syllabus_service.dart';
import '../domain/models/syllabus_model.dart';
import '../../../core/api/api_client.dart';
import '../../../core/auth/auth_provider.dart';

final syllabusServiceProvider = Provider<SyllabusService>((ref) {
  final auth = ref.watch(authProvider);
  final apiClient = ApiClient(token: auth.token);
  return SyllabusService(apiClient);
});

// Syllabus calendar: Day 1-180 with dates and syllabus per day
final syllabusCalendarProvider = FutureProvider.autoDispose.family<SyllabusCalendar, SyllabusCalendarFilter>(
  (ref, filter) async {
    final service = ref.watch(syllabusServiceProvider);
    return service.fetchSyllabusCalendar(
      classId: filter.classId,
      academicYear: filter.academicYear,
    );
  },
);

// Syllabus providers
final syllabusListProvider = FutureProvider.autoDispose.family<List<Syllabus>, SyllabusFilter>(
  (ref, filter) async {
    final service = ref.watch(syllabusServiceProvider);
    return service.fetchSyllabus(
      classId: filter.classId,
      schoolDay: filter.schoolDay,
      academicYearStart: filter.academicYearStart,
    );
  },
);

final syllabusDetailProvider = FutureProvider.autoDispose.family<Syllabus, String>(
  (ref, syllabusId) async {
    final service = ref.watch(syllabusServiceProvider);
    return service.getSyllabusById(syllabusId);
  },
);

// Homework providers
final homeworkListProvider = FutureProvider.autoDispose.family<List<Homework>, HomeworkFilter>(
  (ref, filter) async {
    final service = ref.watch(syllabusServiceProvider);
    return service.fetchHomework(
      classId: filter.classId,
      uploadDate: filter.uploadDate,
    );
  },
);

final homeworkDetailProvider = FutureProvider.autoDispose.family<Homework, String>(
  (ref, homeworkId) async {
    final service = ref.watch(syllabusServiceProvider);
    return service.getHomeworkById(homeworkId);
  },
);

// Filter classes
class SyllabusCalendarFilter {
  final String classId;
  final int? academicYear;

  SyllabusCalendarFilter({required this.classId, this.academicYear});

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SyllabusCalendarFilter &&
          runtimeType == other.runtimeType &&
          classId == other.classId &&
          academicYear == other.academicYear;

  @override
  int get hashCode => classId.hashCode ^ (academicYear?.hashCode ?? 0);
}

class SyllabusFilter {
  final String? classId;
  final int? schoolDay;
  final String? academicYearStart;

  SyllabusFilter({this.classId, this.schoolDay, this.academicYearStart});

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SyllabusFilter &&
          runtimeType == other.runtimeType &&
          classId == other.classId &&
          schoolDay == other.schoolDay &&
          academicYearStart == other.academicYearStart;

  @override
  int get hashCode => classId.hashCode ^ schoolDay.hashCode ^ (academicYearStart?.hashCode ?? 0);
}

class HomeworkFilter {
  final String? classId;
  final String? uploadDate;

  HomeworkFilter({this.classId, this.uploadDate});

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is HomeworkFilter &&
          runtimeType == other.runtimeType &&
          classId == other.classId &&
          uploadDate == other.uploadDate;

  @override
  int get hashCode => classId.hashCode ^ uploadDate.hashCode;
}
