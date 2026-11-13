
import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;

class ApiService {
  ApiService._();

  static const String baseUrl = 'https://redloop.safolota.com/api';

  static const FlutterSecureStorage _secureStorage =
      FlutterSecureStorage();

  static const String _tokenKey = 'redloop_sanctum_token';

  static const Duration _timeout = Duration(seconds: 30);

  static Future<String?> getToken() async {
    return await _secureStorage.read(key: _tokenKey);
  }

  static Future<void> saveToken(String token) async {
    await _secureStorage.write(
      key: _tokenKey,
      value: token,
    );
  }

  static Future<void> clearToken() async {
    await _secureStorage.delete(key: _tokenKey);
  }

  static Uri _buildUri(
    String endpoint, {
    Map<String, String>? query,
  }) {
    final cleanEndpoint = endpoint.startsWith('/')
        ? endpoint.substring(1)
        : endpoint;

    return Uri.parse('$baseUrl/$cleanEndpoint').replace(
      queryParameters: query,
    );
  }

  static Future<Map<String, String>> _headers({
    bool authenticated = true,
  }) async {
    final headers = <String, String>{
      'Accept': 'application/json',
      'Content-Type': 'application/json',
    };

    if (authenticated) {
      final token = await getToken();

      if (token != null && token.isNotEmpty) {
        headers['Authorization'] = 'Bearer $token';
      }
    }

    return headers;
  }

  static Map<String, dynamic> _decodeResponse(
    http.Response response,
  ) {
    Map<String, dynamic> result;

    try {
      final decoded = jsonDecode(response.body);

      if (decoded is Map<String, dynamic>) {
        result = Map<String, dynamic>.from(decoded);
      } else {
        result = {
          'data': decoded,
        };
      }
    } catch (_) {
      result = {
        'message': response.body.isEmpty
            ? 'সার্ভার থেকে কোনো উত্তর পাওয়া যায়নি।'
            : 'সার্ভারের উত্তর বোঝা যায়নি।',
      };
    }

    result['success'] = response.statusCode >= 200 &&
        response.statusCode < 300;

    result['status_code'] = response.statusCode;

    return result;
  }

  static Future<Map<String, dynamic>> _request(
    String method,
    String endpoint, {
    Map<String, dynamic>? body,
    Map<String, String>? query,
    bool authenticated = true,
  }) async {
    try {
      final uri = _buildUri(
        endpoint,
        query: query,
      );

      final headers = await _headers(
        authenticated: authenticated,
      );

      final encodedBody = body == null
          ? null
          : jsonEncode(body);

      late http.Response response;

      switch (method.toUpperCase()) {
        case 'GET':
          response = await http
              .get(uri, headers: headers)
              .timeout(_timeout);
          break;

        case 'POST':
          response = await http
              .post(
                uri,
                headers: headers,
                body: encodedBody,
              )
              .timeout(_timeout);
          break;

        case 'PUT':
          response = await http
              .put(
                uri,
                headers: headers,
                body: encodedBody,
              )
              .timeout(_timeout);
          break;

        case 'PATCH':
          response = await http
              .patch(
                uri,
                headers: headers,
                body: encodedBody,
              )
              .timeout(_timeout);
          break;

        case 'DELETE':
          response = await http
              .delete(
                uri,
                headers: headers,
                body: encodedBody,
              )
              .timeout(_timeout);
          break;

        default:
          return {
            'success': false,
            'message': 'অনুমোদিত API Method নয়।',
          };
      }

      return _decodeResponse(response);
    } on http.ClientException {
      return {
        'success': false,
        'message': 'সার্ভারের সঙ্গে সংযোগ করা যায়নি।',
      };
    } catch (e) {
      return {
        'success': false,
        'message': e.toString().contains('TimeoutException')
            ? 'সার্ভার থেকে উত্তর পেতে দেরি হচ্ছে। আবার চেষ্টা করুন।'
            : 'নেটওয়ার্ক সমস্যা হয়েছে। আবার চেষ্টা করুন।',
      };
    }
  }

  // Login
  static Future<Map<String, dynamic>> login({
    required String identifier,
    required String password,
    bool rememberMe = true,
    String? deviceName,
    String? pushToken,
    String? platform,
  }) async {
    final result = await _request(
      'POST',
      '/login',
      authenticated: false,
      body: {
        'identifier': identifier.trim(),
        'password': password,
        'remember_me': rememberMe,
        'device_name': deviceName ?? 'RedLoop Pro',
        if (pushToken != null) 'push_token': pushToken,
        if (platform != null) 'platform': platform,
      },
    );

    final token = result['token'];

    if (result['success'] == true &&
        token is String &&
        token.isNotEmpty) {
      await saveToken(token);
    }

    return result;
  }

  // Registration
  static Future<Map<String, dynamic>> register({
    required String name,
    required String email,
    required String phone,
    required String password,
    required String passwordConfirmation,
    required bool termsAccepted,
    required String termsVersion,
  }) async {
    final result = await _request(
      'POST',
      '/register',
      authenticated: false,
      body: {
        'name': name.trim(),
        'email': email.trim(),
        'phone': phone.trim(),
        'password': password,
        'password_confirmation': passwordConfirmation,
        'terms_accepted': termsAccepted,
        'terms_version': termsVersion,
      },
    );

    final token = result['token'];

    if (result['success'] == true &&
        token is String &&
        token.isNotEmpty) {
      await saveToken(token);
    }

    return result;
  }

  // Current logged-in user
  static Future<Map<String, dynamic>> getCurrentUser() {
    return _request(
      'GET',
      '/user',
    );
  }

  // Logout
  static Future<Map<String, dynamic>> logout() async {
    final result = await _request(
      'POST',
      '/logout',
    );

    await clearToken();

    return result;
  }

  // GET
  static Future<Map<String, dynamic>> get(
    String endpoint, {
    Map<String, String>? query,
    bool authenticated = true,
  }) {
    return _request(
      'GET',
      endpoint,
      query: query,
      authenticated: authenticated,
    );
  }

  // POST
  static Future<Map<String, dynamic>> post(
    String endpoint, {
    Map<String, dynamic>? body,
    bool authenticated = true,
  }) {
    return _request(
      'POST',
      endpoint,
      body: body,
      authenticated: authenticated,
    );
  }

  // PUT
  static Future<Map<String, dynamic>> put(
    String endpoint, {
    Map<String, dynamic>? body,
    bool authenticated = true,
  }) {
    return _request(
      'PUT',
      endpoint,
      body: body,
      authenticated: authenticated,
    );
  }

  // PATCH
  static Future<Map<String, dynamic>> patch(
    String endpoint, {
    Map<String, dynamic>? body,
    bool authenticated = true,
  }) {
    return _request(
      'PATCH',
      endpoint,
      body: body,
      authenticated: authenticated,
    );
  }

  // DELETE
  static Future<Map<String, dynamic>> delete(
    String endpoint, {
    Map<String, dynamic>? body,
    bool authenticated = true,
  }) {
    return _request(
      'DELETE',
      endpoint,
      body: body,
      authenticated: authenticated,
    );
  }
}
