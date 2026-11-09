import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:school_app/config/config.dart';
import 'package:school_app/screens/login_page.dart';
import 'package:school_app/screens/required_password_change_page.dart';

void main() {
  Future<void> signIn(WidgetTester tester, MockClient client) async {
    tester.view.physicalSize = const Size(1000, 1800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        home: LoginPage(client: client),
        routes: {
          '/dashboard': (_) => const Scaffold(body: Text('Teacher dashboard')),
          '/select-child': (_) => const Scaffold(body: Text('Choose student')),
        },
      ),
    );
    await tester.enterText(find.byType(TextField).at(0), 'teacher');
    await tester.enterText(find.byType(TextField).at(1), 'temporary-password');
    await tester.tap(find.widgetWithText(ElevatedButton, 'Login'));
    await tester.pumpAndSettle();
  }

  Map<String, dynamic> account({bool reset = false, bool linked = true}) => {
    'token': 'test-token',
    'academicYear': '2026-2027',
    'user': {
      'id': 99,
      'usertype': 'Teacher',
      'email': 'teacher@example.test',
      'staffid': linked ? [7] : [null],
      'mustChangePassword': reset,
    },
  };

  setUp(() => SharedPreferences.setMockInitialValues({}));

  http.Response teacherProfileResponse(http.Request request) {
    expect(request.headers['Authorization'], 'Bearer test-token');
    if (request.url.path == '/api/auth/me') {
      return http.Response(
        '{"profiles":[{"id":7,"user_type":"Teacher","full_name":"Teacher"}]}',
        200,
      );
    }
    expect(request.url.path, '/api/auth/select-profile');
    expect(jsonDecode(request.body), {'userType': 'Teacher', 'profileId': 7});
    return http.Response(
      jsonEncode({
        'token': 'selected-teacher-token',
        'user': {
          'id': 99,
          'usertype': 'Teacher',
          'staffid': [7],
          'mustChangePassword': false,
        },
      }),
      200,
    );
  }

  testWidgets(
    'linked teacher uses configured API and clears previous student selection',
    (tester) async {
      SharedPreferences.setMockInitialValues({
        'selected_child': '{}',
        'student_id': 42,
        'class_id': 3,
      });
      final client = MockClient((request) async {
        if (request.url.path != '/api/auth/login') {
          return teacherProfileResponse(request);
        }
        expect(request.url.toString(), '${AppConfig.baseUrl}/auth/login');
        expect(jsonDecode(request.body)['username'], 'teacher');
        return http.Response(jsonEncode(account()), 200);
      });
      await signIn(tester, client);
      expect(find.text('Teacher dashboard'), findsOneWidget);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getInt('teacher_id'), 7);
      expect(prefs.getInt('student_id'), isNull);
      expect(
        jsonDecode(prefs.getString('selected_child')!)['user_type'],
        'Teacher',
      );
      expect(prefs.getString('auth_token'), 'selected-teacher-token');
      expect(AppConfig.academicYear, '2026-2027');
    },
  );

  testWidgets('teacher without staff link cannot use users.id as staff id', (
    tester,
  ) async {
    final client = MockClient(
      (request) async => request.url.path == '/api/auth/login'
          ? http.Response(jsonEncode(account(linked: false)), 200)
          : http.Response('{"profiles":[]}', 200),
    );
    await signIn(tester, client);
    expect(
      find.text(
        'Your teacher profile is not linked. Please contact the school administrator.',
      ),
      findsOneWidget,
    );
    expect(find.text('Teacher dashboard'), findsNothing);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('auth_token'), isNull);
    expect(prefs.getInt('teacher_id'), isNull);
  });

  testWidgets(
    'temporary password must be changed before opening teacher dashboard',
    (tester) async {
      final requests = <String>[];
      final client = MockClient((request) async {
        requests.add(request.url.path);
        if (request.url.path == '/api/auth/login') {
          return http.Response(jsonEncode(account(reset: true)), 200);
        }
        if (request.url.path != '/api/auth/change-password') {
          return teacherProfileResponse(request);
        }
        expect(request.url.path, '/api/auth/change-password');
        expect(request.headers['Authorization'], 'Bearer test-token');
        expect(jsonDecode(request.body)['newPassword'], 'new-password-123');
        return http.Response(
          '{"message":"Password updated successfully"}',
          200,
        );
      });
      await signIn(tester, client);
      expect(find.byType(RequiredPasswordChangePage), findsOneWidget);
      expect(find.text('Teacher dashboard'), findsNothing);
      expect(requests, ['/api/auth/login']);
      final fields = find.byType(TextFormField);
      await tester.enterText(fields.at(0), 'temporary-password');
      await tester.enterText(fields.at(1), 'new-password-123');
      await tester.enterText(fields.at(2), 'new-password-123');
      final change = find.widgetWithText(ElevatedButton, 'Change password');
      await tester.ensureVisible(change);
      await tester.tap(change);
      await tester.pumpAndSettle();
      expect(find.text('Teacher dashboard'), findsOneWidget);
      expect(requests, [
        '/api/auth/login',
        '/api/auth/change-password',
        '/api/auth/me',
        '/api/auth/select-profile',
      ]);
      final prefs = await SharedPreferences.getInstance();
      expect(
        jsonDecode(prefs.getString('user_data')!)['mustChangePassword'],
        false,
      );
    },
  );

  testWidgets('student login loads teacher and student selection options', (
    tester,
  ) async {
    final requests = <String>[];
    final client = MockClient((request) async {
      requests.add(request.url.path);
      if (request.url.path == '/api/auth/login') {
        final data = account();
        (data['user'] as Map<String, dynamic>)['usertype'] = 'Student';
        return http.Response(jsonEncode(data), 200);
      }
      expect(request.url.path, '/api/auth/me');
      expect(request.headers['Authorization'], 'Bearer test-token');
      return http.Response(
        '{"profiles":[{"id":1,"user_type":"Teacher"},{"id":2,"user_type":"Student"}]}',
        200,
      );
    });
    await signIn(tester, client);
    expect(find.text('Choose student'), findsOneWidget);
    expect(requests, ['/api/auth/login', '/api/auth/me']);
  });

  testWidgets(
    'teacher login with children opens profile selection before dashboard',
    (tester) async {
      final client = MockClient((request) async {
        if (request.url.path == '/api/auth/login') {
          return http.Response(jsonEncode(account()), 200);
        }
        expect(request.url.path, '/api/auth/me');
        return http.Response(
          '{"profiles":[{"id":7,"user_type":"Teacher"},{"id":2,"user_type":"Student"}]}',
          200,
        );
      });
      await signIn(tester, client);
      expect(find.text('Choose student'), findsOneWidget);
      expect(find.text('Teacher dashboard'), findsNothing);
    },
  );

  testWidgets('child API failure stays on login and displays server error', (
    tester,
  ) async {
    var childRequests = 0;
    final client = MockClient((request) async {
      if (request.url.path == '/api/auth/login') {
        final data = account();
        (data['user'] as Map<String, dynamic>)['usertype'] = 'Parent';
        return http.Response(jsonEncode(data), 200);
      }
      childRequests++;
      return http.Response('{"error":"Error Fetching Child List"}', 500);
    });
    await signIn(tester, client);
    expect(find.byType(LoginPage), findsOneWidget);
    expect(
      find.textContaining('school server returned an error (500)'),
      findsOneWidget,
    );
    expect(find.text('Choose student'), findsNothing);
    expect(childRequests, 1);
  });

  testWidgets(
    'cancelling required password change clears the authenticated session',
    (tester) async {
      final client = MockClient(
        (_) async => http.Response(jsonEncode(account(reset: true)), 200),
      );
      await signIn(tester, client);
      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();
      expect(find.byType(LoginPage), findsOneWidget);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('auth_token'), isNull);
      expect(prefs.getString('user_data'), isNull);
    },
  );
}
