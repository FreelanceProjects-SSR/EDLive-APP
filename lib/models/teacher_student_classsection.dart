// models/teacher_student_classsection.dart

class StudentClassSection {
  final int id;
  final String name;
  final String admissionNo;
  final int? classId;
  final String className;
  final String section;

  StudentClassSection({
    required this.id,
    required this.name,
    required this.admissionNo,
    this.classId,
    this.className = '',
    this.section = '',
  });

  factory StudentClassSection.fromJson(Map<String, dynamic> json) {
    return StudentClassSection(
      id: _readInt(json['id'] ?? json['student_id'] ?? json['studentId']),
      name: _readString(
        json['student_name'] ??
            json['full_name'] ??
            json['studentName'] ??
            json['name'],
      ),
      admissionNo: _readString(json['admission_no'] ?? json['admissionNo']),
      classId: _readNullableInt(
        json['class_id'] ??
            json['classId'] ??
            json['class_section_id'] ??
            json['classSectionId'],
      ),
      className: _readString(json['class_name'] ?? json['class']),
      section: _readString(json['section']),
    );
  }

  String get displayName => name.isNotEmpty ? name : 'Student #$id';
}

int _readInt(dynamic value) {
  return _readNullableInt(value) ?? 0;
}

int? _readNullableInt(dynamic value) {
  if (value == null) {
    return null;
  }

  if (value is int) {
    return value;
  }

  return int.tryParse(value.toString());
}

String _readString(dynamic value) {
  return value?.toString() ?? '';
}
