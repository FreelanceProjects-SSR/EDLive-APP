import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:school_app/screens/students/select_child_page.dart';

void main() {
  testWidgets(
    'selection displays teacher and students and activates the chosen teacher session',
    (tester) async {
      tester.view.physicalSize = const Size(1000, 1800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      SharedPreferences.setMockInitialValues({
        'auth_token': 'student-token',
        'user_type': 'student',
        'user_data': '{"id":10,"usertype":"Student"}',
      });
      final requests = <String>[];
      final client = MockClient((request) async {
        requests.add(request.url.path);
        expect(request.headers['Authorization'], 'Bearer student-token');
        if (request.url.path == '/api/auth/me') {
          return http.Response(
            jsonEncode({
              'profiles': [
                {
                  'id': 7,
                  'user_type': 'Teacher',
                  'full_name': 'Teacher Parent',
                },
                {'id': 7, 'user_type': 'Student', 'full_name': 'First Child'},
                {'id': 8, 'user_type': 'Student', 'full_name': 'Second Child'},
              ],
            }),
            200,
          );
        }
        expect(request.url.path, '/api/auth/select-profile');
        expect(jsonDecode(request.body), {
          'profileId': 7,
          'userType': 'Teacher',
        });
        return http.Response(
          '{"token":"teacher-token","user":{"id":10,"usertype":"Teacher","staffid":[7]}}',
          200,
        );
      });
      await tester.pumpWidget(
        MaterialApp(
          home: SelectChildPage(client: client),
          routes: {
            '/dashboard': (_) =>
                const Scaffold(body: Text('Chosen teacher dashboard')),
          },
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Teacher Parent'), findsOneWidget);
      expect(find.text('First Child'), findsOneWidget);
      expect(find.text('Second Child'), findsOneWidget);
      await tester.tap(find.text('Teacher Parent'));
      await tester.pumpAndSettle();
      expect(find.text('Chosen teacher dashboard'), findsOneWidget);
      expect(requests, ['/api/auth/me', '/api/auth/select-profile']);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('auth_token'), 'teacher-token');
      expect(prefs.getString('user_type'), 'teacher');
      expect(prefs.getInt('teacher_id'), 7);
    },
  );
}
