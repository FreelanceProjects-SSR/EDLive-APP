import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:school_app/services/login_profile_service.dart';

void main() {
  setUp(
    () => SharedPreferences.setMockInitialValues({
      'auth_token': 'login-token',
      'user_type': 'teacher',
      'teacher_id': 7,
      'student_id': 99,
      'class_id': 10,
      'teacher_profile_image': 'old-image',
    }),
  );

  test(
    'switching teacher to student and back stores scoped tokens and clears stale IDs',
    () async {
      var expectedToken = 'login-token';
      final service = LoginProfileService(
        MockClient((request) async {
          expect(request.url.path, '/api/auth/select-profile');
          expect(request.headers['Authorization'], 'Bearer $expectedToken');
          final body = jsonDecode(request.body);
          expect(body['profileId'], 7);
          final type = body['userType'];
          expectedToken = '$type-token';
          return http.Response(
            jsonEncode({
              'token': expectedToken,
              'user': {
                'id': 1,
                'usertype': type,
                'staffid': type == 'Teacher' ? [7] : [],
              },
            }),
            200,
          );
        }),
      );
      // IDs can overlap between the staff and student tables.
      await service.select({'id': 7, 'user_type': 'Student', 'class_id': 3});
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('auth_token'), 'Student-token');
      expect(prefs.getString('user_type'), 'student');
      expect(prefs.getInt('student_id'), 7);
      expect(prefs.getInt('class_id'), 3);
      expect(prefs.getInt('teacher_id'), isNull);
      expect(prefs.getString('teacher_profile_image'), isNull);

      await service.select({'id': 7, 'user_type': 'Teacher'});
      expect(prefs.getString('auth_token'), 'Teacher-token');
      expect(prefs.getString('user_type'), 'teacher');
      expect(prefs.getInt('teacher_id'), 7);
      expect(prefs.getInt('student_id'), isNull);
      expect(prefs.getInt('class_id'), isNull);
      expect(jsonDecode(prefs.getString('user_data')!)['staffid'], [7]);
    },
  );

  test('a rejected profile leaves the previous session intact', () async {
    final service = LoginProfileService(
      MockClient(
        (_) async => http.Response(
          '{"error":"This profile is not linked to your account"}',
          403,
        ),
      ),
    );
    await expectLater(
      service.select({'id': 7, 'user_type': 'Student'}),
      throwsA(isA<Exception>()),
    );
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('auth_token'), 'login-token');
    expect(prefs.getString('user_type'), 'teacher');
    expect(prefs.getInt('teacher_id'), 7);
  });

  test(
    'student without a class can be selected and stale class is cleared',
    () async {
      final service = LoginProfileService(
        MockClient(
          (_) async => http.Response(
            '{"token":"student-token","user":{"id":1,"usertype":"Student"}}',
            200,
          ),
        ),
      );
      await service.select({'id': 8, 'user_type': 'Student', 'class_id': null});
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getInt('student_id'), 8);
      expect(prefs.getInt('class_id'), isNull);
    },
  );

  test('malformed session response does not replace the login token', () async {
    final service = LoginProfileService(
      MockClient((_) async => http.Response('{}', 200)),
    );
    await expectLater(
      service.select({'id': 7, 'user_type': 'Teacher'}),
      throwsA(isA<Exception>()),
    );
    expect(
      (await SharedPreferences.getInstance()).getString('auth_token'),
      'login-token',
    );
  });
}
