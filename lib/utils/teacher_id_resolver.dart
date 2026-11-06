import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

class TeacherIdResolver {
  const TeacherIdResolver._();

  static int? resolveFromPrefs(SharedPreferences prefs) {
    final storedTeacherId = prefs.getInt('teacher_id');
    if (storedTeacherId != null && storedTeacherId > 0) {
      return storedTeacherId;
    }

    return _extractTeacherIdFromJson(prefs.getString('selected_child')) ??
        _extractTeacherIdFromJson(prefs.getString('user_data'));
  }

  static int? _extractTeacherIdFromJson(String? rawJson) {
    if (rawJson == null || rawJson.trim().isEmpty) {
      return null;
    }

    try {
      final decoded = json.decode(rawJson);
      if (decoded is! Map<String, dynamic>) {
        return null;
      }

      return _extractPositiveInt(decoded['staffid']) ??
          _extractPositiveInt(decoded['teacher_id']) ??
          _extractPositiveInt(decoded['staff_id']) ??
          _extractPositiveInt(decoded['staffId']) ??
          _extractPositiveInt(decoded['teacherId']) ??
          _extractPositiveInt(decoded['id']) ??
          _extractPositiveInt(decoded['user_id']);
    } catch (_) {
      return null;
    }
  }

  static int? _extractPositiveInt(dynamic value) {
    if (value is int && value > 0) {
      return value;
    }

    if (value is String) {
      final parsed = int.tryParse(value.trim());
      if (parsed != null && parsed > 0) {
        return parsed;
      }
    }

    if (value is List) {
      for (final item in value) {
        final parsed = _extractPositiveInt(item);
        if (parsed != null) {
          return parsed;
        }
      }
    }

    return null;
  }
}
