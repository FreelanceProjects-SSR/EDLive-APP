import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:school_app/config/config.dart';
import 'package:school_app/services/profile_image_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({'auth_token': 'token'}));

  test(
    'protected profile image includes bearer token and returns bytes',
    () async {
      const path = '/content/uploads/5/profile-images/photo.jpg';
      final service = ProfileImageService(
        client: MockClient((request) async {
          expect(request.url.toString(), AppConfig.absoluteUrl(path));
          expect(request.headers['Authorization'], 'Bearer token');
          expect(request.url.queryParameters.containsKey('token'), isFalse);
          return http.Response.bytes([1, 2, 3], 200);
        }),
      );
      expect(await service.load(path), [1, 2, 3]);
    },
  );

  test('external image hosts never receive the session token', () async {
    final service = ProfileImageService(
      client: MockClient((request) async {
        expect(request.headers['Authorization'], isNull);
        return http.Response.bytes([1], 200);
      }),
    );
    expect(await service.load('https://images.example.test/photo.jpg'), [1]);
  });

  test('missing session prevents protected image request', () async {
    SharedPreferences.setMockInitialValues({});
    final service = ProfileImageService(
      client: MockClient((_) async {
        fail('Should not request protected image without a token');
      }),
    );
    await expectLater(
      service.load('/content/uploads/photo.jpg'),
      throwsStateError,
    );
  });

  test('unauthorized response is not returned as image bytes', () async {
    final service = ProfileImageService(
      client: MockClient(
        (_) async => http.Response('{"error":"Unauthorized"}', 401),
      ),
    );
    await expectLater(
      service.load('/content/uploads/photo.jpg'),
      throwsA(isA<http.ClientException>()),
    );
  });
}
