import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:school_app/config/config.dart';
import 'package:school_app/utils/class_sorter.dart';

class TeacherClass {
  final int id;
  final String className;
  final String section;
  final String fullName;

  TeacherClass({
    required this.id,
    required this.className,
    required this.section,
    required this.fullName,
  });

  factory TeacherClass.fromJson(Map<String, dynamic> json) {
    final fullName = json['class_name']?.toString() ?? '';
    final className = json['class']?.toString() ?? fullName;
    final section = json['section']?.toString() ?? '';
    return TeacherClass(
      id: _readInt(json['class_id'] ?? json['id'] ?? json['classId']),
      className: className,
      section: section,
      fullName: fullName.isNotEmpty ? fullName : '$className$section',
    );
  }
}

int _readInt(dynamic value) {
  if (value is int) {
    return value;
  }

  return int.tryParse(value?.toString() ?? '') ?? 0;
}

class TeacherClassService {
  Future<List<TeacherClass>> fetchTeacherClasses() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('auth_token');

    if (token == null) {
      throw Exception("No auth token found");
    }

    final url = Uri.parse("${AppConfig.baseUrl}/staff/staff/teacher/class");

    final response = await http.get(
      url,
      headers: {
        "Authorization": "Bearer $token",
        "Content-Type": "application/json",
      },
    );

    if (response.statusCode == 200) {
      final List data = jsonDecode(response.body);
      return data.map((e) => TeacherClass.fromJson(e)).toList()..sort(
        (a, b) => compareClassAndSection(
          classA: a.className,
          sectionA: a.section,
          classB: b.className,
          sectionB: b.section,
        ),
      );
    } else {
      throw Exception("Failed to load teacher classes: ${response.body}");
    }
  }
}
