class Student {
  final int id;
  final String studentName;
  final String className;
  final int? classId;
  final String section;
  final String? profileImagePath;

  Student({
    required this.id,
    required this.studentName,
    required this.className,
    this.classId,
    this.section = '',
    this.profileImagePath,
  });

  factory Student.fromJson(Map<String, dynamic> json) {
    return Student(
      id: _readInt(json['id'] ?? json['student_id'] ?? json['studentId']),
      studentName: _readString(
        json['student_name'] ?? json['full_name'] ?? json['name'],
      ),
      className: _readString(json['class_name'] ?? json['class']),
      classId: _readNullableInt(
        json['class_id'] ?? json['classId'] ?? json['class_section_id'],
      ),
      section: _readString(json['section']),
      profileImagePath:
          json['profile_img']?.toString() ??
          json['profileImage']?.toString() ??
          json['profile_image']?.toString() ??
          json['image']?.toString(),
    );
  }
}

int _readInt(dynamic value) {
  return _readNullableInt(value) ?? 0;
}

int? _readNullableInt(dynamic value) {
  if (value is int) {
    return value;
  }

  return int.tryParse(value?.toString() ?? '');
}

String _readString(dynamic value) {
  return value?.toString() ?? '';
}
