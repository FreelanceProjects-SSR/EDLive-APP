import 'dart:async';
import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'package:school_app/config/config.dart';

enum UserManagementTab { admin, staff, student }

extension UserManagementTabX on UserManagementTab {
  String get label {
    switch (this) {
      case UserManagementTab.admin:
        return 'Admin';
      case UserManagementTab.staff:
        return 'Staff';
      case UserManagementTab.student:
        return 'Student';
    }
  }

  String get apiValue => label.toLowerCase();

  String get addButtonLabel => 'Add $label';
}

class AdminManagedUser {
  final String id;
  final String firstName;
  final String lastName;
  final String email;
  final String role;
  final String status;
  final String studentId;
  final String className;
  final String division;
  final bool loginEnabled;
  final bool firstLoginResetRequired;

  const AdminManagedUser({
    required this.id,
    required this.firstName,
    required this.lastName,
    required this.email,
    required this.role,
    required this.status,
    required this.studentId,
    required this.className,
    required this.division,
    required this.loginEnabled,
    required this.firstLoginResetRequired,
  });

  String get fullName {
    final name = '$firstName $lastName'.trim();
    return name.isEmpty ? '-' : name;
  }

  factory AdminManagedUser.fromJson(Map<String, dynamic> json) {
    return AdminManagedUser(
      id: _stringValue(
        json['id'] ??
            json['user_id'] ??
            json['userid'] ??
            json['staffid'] ??
            json['student_db_id'],
      ),
      firstName: _stringValue(
        json['first_name'] ?? json['firstname'] ?? json['firstName'],
      ),
      lastName: _stringValue(
        json['last_name'] ?? json['lastname'] ?? json['lastName'],
      ),
      email: _stringValue(json['email'] ?? json['username']),
      role: _stringValue(json['role'] ?? json['usertype'] ?? json['user_type']),
      status: _stringValue(
        json['status'] ?? json['profile_status'] ?? json['login_status'],
      ),
      studentId: _stringValue(
        json['student_id'] ?? json['studentId'] ?? json['admission_no'],
      ),
      className: _stringValue(
        json['class'] ?? json['class_name'] ?? json['classname'],
      ),
      division: _stringValue(
        json['division'] ?? json['section'] ?? json['division_name'],
      ),
      loginEnabled: _boolValue(
        json['login_enabled'] ?? json['loginEnabled'] ?? json['has_login'],
      ),
      firstLoginResetRequired: _boolValue(
        json['first_login_password_reset_required'] ??
            json['password_reset_required'] ??
            json['must_change_password'],
      ),
    );
  }

  static String _stringValue(dynamic value) {
    if (value == null) {
      return '';
    }
    if (value is List && value.isNotEmpty) {
      return _stringValue(value.first);
    }
    return value.toString().trim();
  }

  static bool _boolValue(dynamic value) {
    if (value is bool) {
      return value;
    }
    final normalized = value?.toString().trim().toLowerCase() ?? '';
    return normalized == 'true' || normalized == '1' || normalized == 'yes';
  }
}

class AdminUserManagementException implements Exception {
  final String message;
  final Map<String, String> fieldErrors;

  const AdminUserManagementException(
    this.message, {
    this.fieldErrors = const {},
  });

  @override
  String toString() => message;
}

class AdminUserManagementService {
  static final RegExp _emailPattern = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$');

  Future<List<AdminManagedUser>> fetchUsers(UserManagementTab tab) async {
    final response = await _send(
      () async => http.get(
        AppConfig.apiUri(
          '/admin/users',
          queryParameters: {'category': tab.apiValue},
        ),
        headers: await _headers(),
      ),
    );

    if (response.statusCode != 200) {
      throw AdminUserManagementException(_extractHttpError(response));
    }

    final decoded = _decode(response);
    final users = _extractList(decoded)
        .whereType<Map>()
        .map(
          (item) => AdminManagedUser.fromJson(Map<String, dynamic>.from(item)),
        )
        .where((user) => _belongsToTab(user, tab))
        .toList();

    return users;
  }

  Future<String> createUser({
    required UserManagementTab tab,
    required Map<String, dynamic> formData,
  }) async {
    final payload = _buildCreatePayload(tab: tab, formData: formData);

    final response = await _send(
      () async => http.post(
        AppConfig.apiUri('/admin/users'),
        headers: await _headers(json: true),
        body: jsonEncode(payload),
      ),
    );

    if (response.statusCode != 200 && response.statusCode != 201) {
      throw AdminUserManagementException(
        _normalizeDuplicateEmailError(_extractHttpError(response)),
        fieldErrors: _extractFieldErrors(response),
      );
    }

    return _extractSuccessMessage(
      response,
      fallback: '${tab.label} created successfully.',
    );
  }

  Future<String> resendWelcomeEmail(AdminManagedUser user) async {
    if (user.email.trim().isEmpty) {
      throw const AdminUserManagementException(
        'This user does not have an email address for welcome email delivery.',
      );
    }

    final response = await _send(
      () async => http.post(
        AppConfig.apiUri(
          '/admin/users/${Uri.encodeComponent(user.id)}/resend-welcome-email',
        ),
        headers: await _headers(json: true),
        body: jsonEncode({'email': normalizeEmail(user.email)}),
      ),
    );

    if (response.statusCode != 200) {
      throw AdminUserManagementException(_extractHttpError(response));
    }

    return _extractSuccessMessage(
      response,
      fallback: 'Welcome email sent to ${normalizeEmail(user.email)}.',
    );
  }

  Future<String> bulkUploadStudents(PlatformFile file) async {
    final bytes = file.bytes;
    if (bytes == null || bytes.isEmpty) {
      throw const AdminUserManagementException(
        'Could not read the selected file. Please select the Excel file again.',
      );
    }

    final request = http.MultipartRequest(
      'POST',
      AppConfig.apiUri('/admin/users/students/bulk-upload'),
    );
    request.headers.addAll(await _headers());
    request.files.add(
      http.MultipartFile.fromBytes('file', bytes, filename: file.name),
    );

    final streamed = await _sendStream(() async => request.send());
    final response = await http.Response.fromStream(streamed);

    if (response.statusCode != 200 && response.statusCode != 201) {
      throw AdminUserManagementException(_extractHttpError(response));
    }

    return _extractSuccessMessage(
      response,
      fallback: 'Students uploaded successfully.',
    );
  }

  Map<String, dynamic> _buildCreatePayload({
    required UserManagementTab tab,
    required Map<String, dynamic> formData,
  }) {
    final role = formData['role']?.toString().trim() ?? '';
    final email = normalizeEmail(formData['email']?.toString() ?? '');
    final loginEnabled = _shouldEnableLogin(tab: tab, role: role, email: email);

    return {
      ...formData,
      'category': tab.apiValue,
      'user_type': tab.apiValue,
      'role': role,
      'email': email.isEmpty ? null : email,
      'username': loginEnabled ? email : null,
      'login_enabled': loginEnabled,
      'generate_temporary_password': loginEnabled,
      'first_login_password_reset_required': loginEnabled,
      'send_welcome_email': loginEnabled,
    }..removeWhere((_, value) => value == null);
  }

  bool _shouldEnableLogin({
    required UserManagementTab tab,
    required String role,
    required String email,
  }) {
    if (tab == UserManagementTab.staff) {
      return role.toLowerCase() == 'teacher';
    }
    if (tab == UserManagementTab.student) {
      return email.isNotEmpty;
    }
    return false;
  }

  bool _belongsToTab(AdminManagedUser user, UserManagementTab tab) {
    final role = user.role.toLowerCase();
    switch (tab) {
      case UserManagementTab.admin:
        return role.contains('admin');
      case UserManagementTab.staff:
        return !role.contains('admin') && !role.contains('student');
      case UserManagementTab.student:
        return role.contains('student') || user.studentId.isNotEmpty;
    }
  }

  Future<Map<String, String>> _headers({bool json = false}) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('auth_token')?.trim() ?? '';
    return {
      'accept': 'application/json',
      if (json) 'Content-Type': 'application/json',
      if (token.isNotEmpty) 'Authorization': 'Bearer $token',
    };
  }

  Future<http.Response> _send(Future<http.Response> Function() action) async {
    try {
      return await action().timeout(const Duration(seconds: 30));
    } on TimeoutException {
      throw const AdminUserManagementException(
        'The server took too long to respond. Please try again.',
      );
    } catch (error) {
      throw AdminUserManagementException(AppConfig.networkErrorMessage(error));
    }
  }

  Future<http.StreamedResponse> _sendStream(
    Future<http.StreamedResponse> Function() action,
  ) async {
    try {
      return await action().timeout(const Duration(seconds: 60));
    } on TimeoutException {
      throw const AdminUserManagementException(
        'The upload took too long to respond. Please try again.',
      );
    } catch (error) {
      throw AdminUserManagementException(AppConfig.networkErrorMessage(error));
    }
  }

  static String normalizeEmail(String value) => value.trim().toLowerCase();

  static String? validateEmail(String value, {required bool required}) {
    final normalized = normalizeEmail(value);
    if (normalized.isEmpty) {
      return required ? 'Email is required.' : null;
    }
    if (!_emailPattern.hasMatch(normalized)) {
      return 'Enter a valid email address.';
    }
    return null;
  }

  dynamic _decode(http.Response response) {
    final body = utf8.decode(response.bodyBytes, allowMalformed: true).trim();
    if (body.isEmpty) {
      return null;
    }
    return jsonDecode(body);
  }

  List<dynamic> _extractList(dynamic decoded) {
    if (decoded is List) {
      return decoded;
    }
    if (decoded is Map) {
      for (final key in const ['data', 'users', 'results', 'items']) {
        final value = decoded[key];
        if (value is List) {
          return value;
        }
      }
    }
    return const [];
  }

  String _extractSuccessMessage(
    http.Response response, {
    required String fallback,
  }) {
    try {
      final message = _extractErrorText(_decode(response));
      if (message != null && message.isNotEmpty) {
        return message;
      }
    } catch (_) {
      // Ignore malformed success bodies.
    }
    return fallback;
  }

  String _extractHttpError(http.Response response) {
    final body = utf8.decode(response.bodyBytes, allowMalformed: true).trim();
    if (body.isNotEmpty) {
      try {
        final message = _extractErrorText(jsonDecode(body));
        if (message != null && message.isNotEmpty) {
          return message;
        }
      } catch (_) {
        final plainText = _stripHtml(body);
        if (plainText.isNotEmpty) {
          return plainText;
        }
      }
    }

    final reasonPhrase = response.reasonPhrase?.trim();
    if (reasonPhrase != null && reasonPhrase.isNotEmpty) {
      return reasonPhrase;
    }

    return 'Request failed with status ${response.statusCode}.';
  }

  String _normalizeDuplicateEmailError(String message) {
    final normalized = message.toLowerCase();
    final looksLikeDuplicateEmail =
        normalized.contains('email') &&
        (normalized.contains('exist') ||
            normalized.contains('duplicate') ||
            normalized.contains('already') ||
            normalized.contains('unique'));
    if (looksLikeDuplicateEmail) {
      return 'A user with this email address already exists.';
    }
    return message;
  }

  Map<String, String> _extractFieldErrors(http.Response response) {
    try {
      final decoded = _decode(response);
      if (decoded is! Map) {
        return const {};
      }

      final fields =
          decoded['fields'] ?? decoded['fieldErrors'] ?? decoded['errors'];
      if (fields is! Map) {
        return const {};
      }

      return fields.map(
        (key, value) =>
            MapEntry(key.toString(), _extractErrorText(value) ?? ''),
      )..removeWhere((_, value) => value.isEmpty);
    } catch (_) {
      return const {};
    }
  }

  String? _extractErrorText(dynamic value) {
    if (value is String) {
      final message = value.trim();
      return message.isEmpty ? null : message;
    }
    if (value is List) {
      for (final item in value) {
        final message = _extractErrorText(item);
        if (message != null && message.isNotEmpty) {
          return message;
        }
      }
      return null;
    }
    if (value is Map) {
      for (final key in const ['message', 'error', 'detail', 'title', 'msg']) {
        final message = _extractErrorText(value[key]);
        if (message != null && message.isNotEmpty) {
          return message;
        }
      }
      for (final item in value.values) {
        final message = _extractErrorText(item);
        if (message != null && message.isNotEmpty) {
          return message;
        }
      }
    }
    return null;
  }

  String _stripHtml(String value) {
    return value
        .replaceAll(
          RegExp(r'<script[^>]*>[\s\S]*?</script>', caseSensitive: false),
          ' ',
        )
        .replaceAll(
          RegExp(r'<style[^>]*>[\s\S]*?</style>', caseSensitive: false),
          ' ',
        )
        .replaceAll(RegExp(r'<[^>]+>'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }
}
