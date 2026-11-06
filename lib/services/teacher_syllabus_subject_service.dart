import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/teacher_syllabus_subject_model.dart';
import 'package:school_app/config/config.dart';
import 'package:school_app/utils/api_response_parser.dart';

class SubjectService {
  Future<List<SubjectModel>> fetchSubjects({int? classId}) async {
    final url = classId == null
        ? AppConfig.apiUri('/master/subjects')
        : AppConfig.apiUri('/syllabus/subjects/$classId');

    final response = await http.get(
      url,
      headers: {"accept": "application/json"},
    );

    if (response.statusCode == 200) {
      final data = extractJsonList(
        jsonDecode(response.body),
        preferredKeys: const <String>['subjects', 'data'],
      );
      return data
          .map((e) => SubjectModel.fromJson(asStringKeyedMap(e)))
          .toList();
    } else {
      throw Exception("Failed to load subjects: ${response.body}");
    }
  }
}
