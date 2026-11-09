import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:school_app/config/config.dart';
import '../models/teacher_model.dart';

class TeacherListException implements Exception {
  const TeacherListException(this.message);

  final String message;

  @override
  String toString() => message;
}

class TeacherService {
  const TeacherService({this.client});

  final http.Client? client;
  String get baseUrl => AppConfig.baseUrl;

  Future<List<Teacher>> fetchTeachers(String studentId) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('auth_token')?.trim() ?? '';
    if (token.isEmpty) {
      throw const TeacherListException('Session expired. Please login again.');
    }

    final url = AppConfig.apiUri('/student/students/$studentId/teachers');
    final headers = {
      'Authorization': 'Bearer $token',
      'Accept': 'application/json',
    };
    final http.Response response;
    try {
      response =
          await (client == null
                  ? http.get(url, headers: headers)
                  : client!.get(url, headers: headers))
              .timeout(const Duration(seconds: 20));
    } on TimeoutException {
      throw const TeacherListException(
        'The server took too long to load teachers. Please try again.',
      );
    } on http.ClientException catch (error) {
      throw TeacherListException(AppConfig.networkErrorMessage(error));
    }

    dynamic data;
    try {
      data = jsonDecode(utf8.decode(response.bodyBytes));
    } on FormatException {
      // Non-JSON responses are handled by status or payload validation below.
    }
    if (response.statusCode == 404 &&
        data is Map &&
        data['error'] == 'No Teacher found for this Student') {
      return [];
    }
    if (response.statusCode == 401) {
      throw const TeacherListException('Session expired. Please login again.');
    }
    if (response.statusCode != 200) {
      throw TeacherListException(
        'Unable to load teachers (${response.statusCode}). Please try again.',
      );
    }
    if (data is! List) {
      throw const TeacherListException(
        'The server returned an invalid teacher list.',
      );
    }
    try {
      return data
          .map((item) => Teacher.fromJson(item as Map<String, dynamic>))
          .toList();
    } catch (_) {
      throw const TeacherListException(
        'The server returned an invalid teacher list.',
      );
    }
  }
}
