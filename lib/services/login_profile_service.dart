import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:school_app/config/config.dart';

class LoginProfileService {
  const LoginProfileService(this.client);

  final http.Client client;

  /// Validate the chosen profile on the server and persist its scoped session.
  Future<void> select(Map<String, dynamic> profile) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('auth_token');
    final type = profile['user_type']?.toString().toLowerCase();
    final isTeacher = type == 'teacher' || type == 'staff';
    final id = int.tryParse(profile['id']?.toString() ?? '');
    if (token == null ||
        token.isEmpty ||
        id == null ||
        id <= 0 ||
        !['teacher', 'staff', 'student'].contains(type)) {
      throw Exception('Please login again and select a valid profile.');
    }
    final response = await client
        .post(
          AppConfig.apiUri('/auth/select-profile'),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $token',
          },
          body: jsonEncode({
            'userType': isTeacher ? 'Teacher' : 'Student',
            'profileId': id,
          }),
        )
        .timeout(const Duration(seconds: 20));
    Map<String, dynamic>? data;
    try {
      data = jsonDecode(response.body) as Map<String, dynamic>;
    } catch (_) {
      throw Exception('Unable to select this profile. Please try again.');
    }
    if (response.statusCode != 200) {
      throw Exception(
        data['error'] ?? 'Unable to select this profile. Please try again.',
      );
    }
    final selectedToken = data['token'];
    final user = data['user'];
    if (selectedToken is! String ||
        selectedToken.isEmpty ||
        user is! Map<String, dynamic>) {
      throw Exception('The server returned an invalid profile session.');
    }

    await prefs.setString('auth_token', selectedToken);
    await prefs.setString('user_type', isTeacher ? 'teacher' : 'student');
    await prefs.setString('user_data', jsonEncode(user));
    await prefs.setString('selected_child', jsonEncode(profile));
    for (final key in [
      'teacher_id',
      'student_id',
      'class_id',
      'teacher_profile_staff_id',
      'teacher_profile_image',
      'teacher_profile_image_version',
    ]) {
      await prefs.remove(key);
    }
    if (isTeacher) {
      await prefs.setInt('teacher_id', id);
    } else {
      await prefs.setInt('student_id', id);
      final classId = int.tryParse(profile['class_id']?.toString() ?? '');
      if (classId != null && classId > 0) {
        await prefs.setInt('class_id', classId);
      }
    }
  }
}
