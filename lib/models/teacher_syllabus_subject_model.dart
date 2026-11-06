// models/subject_model.dart
class SubjectModel {
  final int id;
  final String name;
  final String code;

  SubjectModel({required this.id, required this.name, required this.code});

  factory SubjectModel.fromJson(Map<String, dynamic> json) {
    return SubjectModel(
      id: _readInt(json['subject_id'] ?? json['id'] ?? json['subjectId']),
      name: _readString(
        json['subject_name'] ?? json['name'] ?? json['subject'],
      ),
      code: _readString(json['subject_code'] ?? json['code']),
    );
  }
}

int _readInt(dynamic value) {
  if (value is int) {
    return value;
  }

  return int.tryParse(value?.toString() ?? '') ?? 0;
}

String _readString(dynamic value) {
  return value?.toString() ?? '';
}
