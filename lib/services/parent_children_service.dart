import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:school_app/config/config.dart';

class ParentChildrenException implements Exception {
  const ParentChildrenException(this.message);

  final String message;

  @override
  String toString() => message;
}

class ParentChildrenService {
  const ParentChildrenService(this.client);

  final http.Client client;

  Future<List<Map<String, dynamic>>> fetch(String? token) => _fetch(token);

  /// The account profile list includes teachers as well as linked students.
  Future<List<Map<String, dynamic>>> fetchProfiles(String? token) =>
      _fetch(token, includeTeachers: true);

  Future<List<Map<String, dynamic>>> _fetch(
    String? token, {
    bool includeTeachers = false,
  }) async {
    final normalizedToken = token?.trim() ?? '';
    if (normalizedToken.isEmpty) {
      throw const ParentChildrenException(
        'Session expired. Please login again.',
      );
    }

    final http.Response response;
    try {
      response = await client
          .get(
            AppConfig.apiUri(
              includeTeachers ? '/auth/me' : '/student/parents/children',
            ),
            headers: {
              'accept': 'application/json',
              'Authorization': 'Bearer $normalizedToken',
            },
          )
          .timeout(const Duration(seconds: 20));
    } on TimeoutException {
      throw const ParentChildrenException(
        'The server took too long to load children. Please try again.',
      );
    } on http.ClientException catch (error) {
      throw ParentChildrenException(AppConfig.networkErrorMessage(error));
    }

    dynamic data;
    try {
      data = jsonDecode(utf8.decode(response.bodyBytes));
    } on FormatException {
      // Handle non-JSON error responses using their HTTP status below.
    }

    if (response.statusCode == 401 || response.statusCode == 403) {
      throw const ParentChildrenException(
        'Session expired. Please login again.',
      );
    }
    if (response.statusCode == 428) {
      throw const ParentChildrenException(
        'Please login again and change your temporary password.',
      );
    }
    // This API explicitly reports an unlinked account as a 404.
    if (!includeTeachers &&
        response.statusCode == 404 &&
        data is Map &&
        data['error'] == 'No children found for this user') {
      return [];
    }
    if (response.statusCode >= 500) {
      throw ParentChildrenException(
        'Unable to load children: the school server returned an error '
        '(${response.statusCode}). Please retry. If this continues, contact the school administrator.',
      );
    }
    if (response.statusCode != 200) {
      throw ParentChildrenException(
        'Unable to load children (${response.statusCode}). Please try again.',
      );
    }
    if (includeTeachers && response.statusCode == 200 && data is Map) {
      // Older servers may not yet expose the combined profile list.
      if (!data.containsKey('profiles')) return fetch(token);
      data = data['profiles'];
    }
    if (data is! List || data.any((child) => child is! Map<String, dynamic>)) {
      throw const ParentChildrenException(
        'The server returned an invalid child list. Please try again.',
      );
    }
    return data.cast<Map<String, dynamic>>();
  }
}
