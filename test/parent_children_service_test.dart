import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:school_app/config/config.dart';
import 'package:school_app/services/parent_children_service.dart';

void main() {
  test(
    'selection uses authenticated profiles including teacher without children',
    () async {
      final service = ParentChildrenService(
        MockClient((request) async {
          expect(request.url, AppConfig.apiUri('/auth/me'));
          expect(request.headers['Authorization'], 'Bearer teacher-token');
          return http.Response(
            '{"id":146,"usertype":"Teacher","profiles":['
            '{"id":43,"user_type":"Teacher","full_name":"Teacher"}]}',
            200,
          );
        }),
      );
      final profiles = await service.fetchProfiles('teacher-token');
      expect(profiles.single['id'], 43);
      expect(profiles.single['user_type'], 'Teacher');
    },
  );

  test(
    'selection retains teachers and children with the same numeric ID',
    () async {
      final service = ParentChildrenService(
        MockClient(
          (_) async => http.Response(
            '{"profiles":[{"id":19,"user_type":"Teacher"},'
            '{"id":19,"user_type":"Student"}]}',
            200,
          ),
        ),
      );
      expect(await service.fetchProfiles('token'), hasLength(2));
    },
  );

  test('older auth response falls back to children endpoint', () async {
    final paths = <String>[];
    final service = ParentChildrenService(
      MockClient((request) async {
        paths.add(request.url.path);
        return request.url.path == '/api/auth/me'
            ? http.Response('{"id":146}', 200)
            : http.Response('[{"id":19,"user_type":"Student"}]', 200);
      }),
    );
    expect(await service.fetchProfiles('token'), hasLength(1));
    expect(paths, ['/api/auth/me', '/api/student/parents/children']);
  });

  test('empty combined profiles do not request children again', () async {
    final service = ParentChildrenService(
      MockClient((request) async {
        expect(request.url.path, '/api/auth/me');
        return http.Response('{"profiles":[]}', 200);
      }),
    );
    expect(await service.fetchProfiles('token'), isEmpty);
  });

  test(
    'profile authentication failure is not replaced with children fallback',
    () async {
      final service = ParentChildrenService(
        MockClient((request) async {
          expect(request.url.path, '/api/auth/me');
          return http.Response('{"error":"Token expired"}', 401);
        }),
      );
      await expectLater(
        service.fetchProfiles('token'),
        throwsA(isA<ParentChildrenException>()),
      );
    },
  );

  test('uses configured endpoint and authenticated parent token', () async {
    final service = ParentChildrenService(
      MockClient((request) async {
        expect(request.method, 'GET');
        expect(request.url, AppConfig.apiUri('/student/parents/children'));
        expect(request.headers['Authorization'], 'Bearer parent-token');
        return http.Response('[{"id":3,"class_id":2}]', 200);
      }),
    );
    expect(await service.fetch(' parent-token '), [
      {'id': 3, 'class_id': 2},
    ]);
  });

  test('missing token makes no request', () async {
    final service = ParentChildrenService(
      MockClient((_) async {
        fail('Must not send an unauthenticated request');
      }),
    );
    await expectLater(
      service.fetch(null),
      throwsA(isA<ParentChildrenException>()),
    );
  });

  test('only documented no-children response is treated as empty', () async {
    final service = ParentChildrenService(
      MockClient(
        (_) async =>
            http.Response('{"error":"No children found for this user"}', 404),
      ),
    );
    expect(await service.fetch('token'), isEmpty);
    final missingRoute = ParentChildrenService(
      MockClient((_) async => http.Response('<html>Not Found</html>', 404)),
    );
    await expectLater(
      missingRoute.fetch('token'),
      throwsA(isA<ParentChildrenException>()),
    );
  });

  test('server failures are errors and a later retry can succeed', () async {
    var calls = 0;
    final service = ParentChildrenService(
      MockClient((_) async {
        calls++;
        return calls == 1
            ? http.Response('{"error":"Error Fetching Child List"}', 500)
            : http.Response('[{"id":3}]', 200);
      }),
    );
    await expectLater(
      service.fetch('token'),
      throwsA(
        isA<ParentChildrenException>().having(
          (error) => error.message,
          'message',
          contains('(500)'),
        ),
      ),
    );
    expect(await service.fetch('token'), [
      {'id': 3},
    ]);
  });

  test('invalid success payload is not an empty list', () async {
    final service = ParentChildrenService(
      MockClient((_) async => http.Response('{"error":"unexpected"}', 200)),
    );
    await expectLater(
      service.fetch('token'),
      throwsA(isA<ParentChildrenException>()),
    );
  });
}
