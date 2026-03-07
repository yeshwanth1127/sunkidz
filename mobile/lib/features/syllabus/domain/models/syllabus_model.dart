class Syllabus {
  final String id;
  final String classId;
  final String uploadedBy;
  final String? uploaderName;
  final String title;
  final String? description;
  final DateTime uploadDate;
  final String filePath;
  final String fileName;
  final String? fileSize;
  final String className;
  final DateTime createdAt;

  Syllabus({
    required this.id,
    required this.classId,
    required this.uploadedBy,
    this.uploaderName,
    required this.title,
    this.description,
    required this.uploadDate,
    required this.filePath,
    required this.fileName,
    this.fileSize,
    required this.className,
    required this.createdAt,
  });

  factory Syllabus.fromJson(Map<String, dynamic> json) {
    return Syllabus(
      id: json['id'],
      classId: json['class_id'],
      uploadedBy: json['uploaded_by'],
      uploaderName: json['uploader_name'],
      title: json['title'],
      description: json['description'],
      uploadDate: DateTime.parse(json['upload_date']),
      filePath: json['file_path'],
      fileName: json['file_name'],
      fileSize: json['file_size'],
      className: json['class_name'],
      createdAt: DateTime.parse(json['created_at']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'class_id': classId,
      'uploaded_by': uploadedBy,
      'uploader_name': uploaderName,
      'title': title,
      'description': description,
      'upload_date': uploadDate.toIso8601String(),
      'file_path': filePath,
      'file_name': fileName,
      'file_size': fileSize,
      'class_name': className,
      'created_at': createdAt.toIso8601String(),
    };
  }
}

class Homework {
  final String id;
  final String classId;
  final String uploadedBy;
  final String? uploaderName;
  final String title;
  final String? description;
  final DateTime uploadDate;
  final DateTime? dueDate;
  final String filePath;
  final String fileName;
  final String? fileSize;
  final String className;
  final DateTime createdAt;

  Homework({
    required this.id,
    required this.classId,
    required this.uploadedBy,
    this.uploaderName,
    required this.title,
    this.description,
    required this.uploadDate,
    this.dueDate,
    required this.filePath,
    required this.fileName,
    this.fileSize,
    required this.className,
    required this.createdAt,
  });

  factory Homework.fromJson(Map<String, dynamic> json) {
    return Homework(
      id: json['id'],
      classId: json['class_id'],
      uploadedBy: json['uploaded_by'],
      uploaderName: json['uploader_name'],
      title: json['title'],
      description: json['description'],
      uploadDate: DateTime.parse(json['upload_date']),
      dueDate: json['due_date'] != null ? DateTime.parse(json['due_date']) : null,
      filePath: json['file_path'],
      fileName: json['file_name'],
      fileSize: json['file_size'],
      className: json['class_name'],
      createdAt: DateTime.parse(json['created_at']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'class_id': classId,
      'uploaded_by': uploadedBy,
      'uploader_name': uploaderName,
      'title': title,
      'description': description,
      'upload_date': uploadDate.toIso8601String(),
      'due_date': dueDate?.toIso8601String(),
      'file_path': filePath,
      'file_name': fileName,
      'file_size': fileSize,
      'class_name': className,
      'created_at': createdAt.toIso8601String(),
    };
  }
}
