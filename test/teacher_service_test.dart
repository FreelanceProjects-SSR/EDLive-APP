import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:school_app/config/config.dart';
import 'package:school_app/services/teacher_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({'auth_token': 'token'}));

  test('loads teachers with selected student ID and bearer token', () async {
    final service = TeacherService(
      client: MockClient((request) async {
        expect(request.url, AppConfig.apiUri('/student/students/19/teachers'));
        expect(request.headers['Authorization'], 'Bearer token');
        return http.Response(
          '[{"id":7,"full_name":"Teacher","staff_id":"S7","subject_name":"Math"}]',
          200,
        );
      }),
    );
    final teachers = await service.fetchTeachers('19');
    expect(teachers.single.id, 7);
    expect(teachers.single.subjectName, 'Math');
  });

  test('documented no-teachers response returns empty list', () async {
    final service = TeacherService(
      client: MockClient(
        (_) async => http.Response(
          '{"error":"No Teacher found for this Student","details":"Student ID: 19"}',
          404,
        ),
      ),
    );
    expect(await service.fetchTeachers('19'), isEmpty);
  });

  test('missing endpoint and server failures are not empty lists', () async {
    for (final status in [404, 500]) {
      final service = TeacherService(
        client: MockClient(
          (_) async => http.Response('<html>Error</html>', status),
        ),
      );
      await expectLater(
        service.fetchTeachers('19'),
        throwsA(
          isA<TeacherListException>().having(
            (error) => error.message,
            'message',
            contains('($status)'),
          ),
        ),
      );
    }
  });

  test(
    'empty result can be refreshed after assignments become available',
    () async {
      var calls = 0;
      final service = TeacherService(
        client: MockClient((_) async {
          calls++;
          return calls == 1
              ? http.Response(
                  '{"error":"No Teacher found for this Student"}',
                  404,
                )
              : http.Response(
                  '[{"id":7,"full_name":"Teacher","staff_id":"S7","subject_name":"Math"}]',
                  200,
                );
        }),
      );
      expect(await service.fetchTeachers('19'), isEmpty);
      expect(await service.fetchTeachers('19'), hasLength(1));
    },
  );

  test('missing session does not send request', () async {
    SharedPreferences.setMockInitialValues({});
    final service = TeacherService(
      client: MockClient((_) async {
        fail('Must not send request without a token');
      }),
    );
    await expectLater(
      service.fetchTeachers('19'),
      throwsA(isA<TeacherListException>()),
    );
  });

  test('invalid success payload reports an error', () async {
    final service = TeacherService(
      client: MockClient(
        (_) async => http.Response('{"unexpected":true}', 200),
      ),
    );
    await expectLater(
      service.fetchTeachers('19'),
      throwsA(isA<TeacherListException>()),
    );
  });
}
