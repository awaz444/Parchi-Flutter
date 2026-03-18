import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../config/api_config.dart';
import '../models/auth_models.dart';
import 'notification_handler_service.dart';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class AuthService {
  static const String _accessTokenKey = 'access_token';
  static const String _refreshTokenKey = 'refresh_token';
  static const String _tokenExpiresAtKey = 'token_expires_at';
  static const String _userKey = 'user';

  bool _isLoggingOut = false; // Logout lock (instance-level, not static)

  final _secureStorage = const FlutterSecureStorage(
    aOptions: AndroidOptions(
      encryptedSharedPreferences: true,
    ),
  );

  // ── Persistent HTTP client — reuses TCP+TLS connections across requests ──
  // This eliminates per-request TLS handshake overhead (saves 200–800ms on
  // mobile). A single instance is shared for the lifetime of the app.
  final http.Client _httpClient;

  // ── In-memory token cache ─────────────────────────────────────────────────
  // Avoids hitting FlutterSecureStorage (Keychain/Keystore disk I/O) on every
  // API call. Invalidated on login, logout, and refresh.
  String? _cachedAccessToken;
  int? _cachedExpiresAt;

  AuthService() : _httpClient = http.Client();

  // ── Standard request headers ──────────────────────────────────────────────
  // Accept-Encoding: gzip tells the server to send compressed responses.
  // The backend already has compression() middleware — browsers send this
  // automatically, but the Dart http package does NOT. This alone can reduce
  // payload size by ~70 % and meaningfully speed up responses on mobile.
  static const Map<String, String> _baseHeaders = {
    'Content-Type': 'application/json',
    'Accept-Encoding': 'gzip',
  };

  // Stream controller for broadcasting auth errors (e.g., account deactivation)
  final _authErrorController = StreamController<String>.broadcast();

  // Expose stream for listeners to react to auth errors
  Stream<String> get onAuthError => _authErrorController.stream;

  // Get stored access token with auto-refresh check.
  // Uses an in-memory cache to avoid Keychain/Keystore disk I/O on every call.
  Future<String?> getToken() async {
    // ── Fast path: serve from memory cache ───────────────────────────────────
    if (_cachedAccessToken != null && _cachedExpiresAt != null) {
      final expiryMs = _cachedExpiresAt! * 1000;
      if (DateTime.now().millisecondsSinceEpoch < expiryMs - 300000) {
        // Token is still valid and not close to expiry — return immediately
        // without touching disk storage.
        return _cachedAccessToken;
      }
    }

    // ── Slow path: read from secure storage (first call / cache miss) ────────
    final expiresAtStr = await _secureStorage.read(key: _tokenExpiresAtKey);
    final expiresAt = expiresAtStr != null ? int.tryParse(expiresAtStr) : null;

    if (expiresAt != null) {
      final expiryTime = expiresAt * 1000; // Convert to milliseconds
      // Check if expired or about to expire (within 5 minutes)
      if (DateTime.now().millisecondsSinceEpoch >= expiryTime - 300000) {
        try {
          print("Token expired or close to expiry. Refreshing...");
          await refreshToken();
          // refreshToken() updates the cache via setToken() / setTokenExpiry()
          return _cachedAccessToken;
        } catch (e) {
          print("Auto-refresh in getToken failed: $e");
          // Return null so callers know auth is required — do NOT return the
          // expired token, as the backend will reject it.
          return null;
        }
      }
    }

    final token = await _secureStorage.read(key: _accessTokenKey);
    // Populate cache so subsequent calls are fast
    _cachedAccessToken = token;
    _cachedExpiresAt = expiresAt;
    return token;
  }

  // Set access token (also updates in-memory cache)
  Future<void> setToken(String token) async {
    _cachedAccessToken = token;
    await _secureStorage.write(key: _accessTokenKey, value: token);
  }

  // Get stored refresh token
  Future<String?> getRefreshToken() async {
    return await _secureStorage.read(key: _refreshTokenKey);
  }

  // Set refresh token
  Future<void> setRefreshToken(String token) async {
    await _secureStorage.write(key: _refreshTokenKey, value: token);
  }

  // Set token expiry (also updates in-memory cache)
  Future<void> setTokenExpiry(int expiresAt) async {
    _cachedExpiresAt = expiresAt;
    await _secureStorage.write(
        key: _tokenExpiresAtKey, value: expiresAt.toString());
  }

  // Get token expiry
  Future<int?> getTokenExpiry() async {
    final str = await _secureStorage.read(key: _tokenExpiresAtKey);
    return str != null ? int.tryParse(str) : null;
  }

  // Store user data
  Future<void> setUser(User user) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_userKey, jsonEncode(user.toJson()));
  }

  // Get stored user data
  Future<User?> getUser() async {
    final prefs = await SharedPreferences.getInstance();
    final userJson = prefs.getString(_userKey);
    if (userJson == null) return null;
    try {
      return User.fromJson(jsonDecode(userJson) as Map<String, dynamic>);
    } catch (e) {
      return null;
    }
  }

  // Remove all stored tokens and user data (also clears in-memory cache)
  Future<void> removeToken() async {
    // Clear in-memory cache immediately
    _cachedAccessToken = null;
    _cachedExpiresAt = null;
    final prefs = await SharedPreferences.getInstance();
    // Remove user data from prefs
    await prefs.remove(_userKey);
    // Remove tokens from secure storage
    await _secureStorage.delete(key: _accessTokenKey);
    await _secureStorage.delete(key: _refreshTokenKey);
    await _secureStorage.delete(key: _tokenExpiresAtKey);
  }

  // Check if user is authenticated
  Future<bool> isAuthenticated() async {
    final token = await getToken();
    if (token == null) return false;

    // Check if token is expired
    final expiresAt = await getTokenExpiry();
    if (expiresAt != null) {
      final expiryTime = expiresAt * 1000; // Convert to milliseconds
      // Check if expired or about to expire (within 5 minutes)
      if (DateTime.now().millisecondsSinceEpoch >= expiryTime - 300000) {
        // Attempt refresh
        try {
          await refreshToken();
          return true;
        } catch (e) {
          // Refresh failed, logout
          await removeToken();
          return false;
        }
      }
    }

    return true;
  }

  // Refresh Token
  Future<void> refreshToken() async {
    // [NEW] Lock check
    if (_isLoggingOut) throw Exception('Session expired');

    final refreshToken = await getRefreshToken();
    if (refreshToken == null) {
      await logout();
      throw Exception('No refresh token available');
    }

    try {
      final response = await _httpClient.post(
        Uri.parse(ApiConfig.refreshEndpoint),
        headers: _baseHeaders,
        body: jsonEncode({
          'refreshToken': refreshToken,
        }),
      );

      final responseData = jsonDecode(response.body) as Map<String, dynamic>;

      if (response.statusCode >= 200 && response.statusCode < 300) {
        final sessionData = responseData['data']['session'];
        if (sessionData != null) {
          if (sessionData['access_token'] != null) {
            await setToken(sessionData['access_token']);
          }
          if (sessionData['refresh_token'] != null) {
            await setRefreshToken(sessionData['refresh_token']);
          }
          if (sessionData['expires_at'] != null) {
            await setTokenExpiry(sessionData['expires_at']);
          } else if (sessionData['expires_in'] != null) {
            final expiresIn = sessionData['expires_in'] as int;
            final expiresAt =
                (DateTime.now().millisecondsSinceEpoch ~/ 1000) + expiresIn;
            await setTokenExpiry(expiresAt);
          }
        }
      } else {
        // Server explicitly rejected the token (4xx/5xx).
        // This is a real auth failure — logout is appropriate.
        String errorMessage;
        if (responseData.containsKey('message')) {
          final msg = responseData['message'];
          errorMessage = (msg is List) ? msg.join(', ') : msg.toString();
        } else if (response.statusCode == 401 || response.statusCode == 403) {
          errorMessage = 'Your session has expired. Please log in again.';
        } else {
          errorMessage = 'Session refresh failed. Please log in again.';
        }
        _authErrorController.add(errorMessage);
        await logout();
        throw Exception(errorMessage);
      }
    } on http.ClientException catch (e) {
      // Network error (no internet, timeout) — do NOT logout.
      // The session may still be valid; user just has no connectivity right now.
      print("Network error during token refresh (will not logout): $e");
      throw Exception(
          'Network error during refresh. Please check your connection.');
    } on FormatException catch (e) {
      // Malformed JSON response — do NOT logout. This is a server/parse error,
      // not an auth failure. The refresh token is still valid.
      print("JSON parse error during token refresh (will not logout): $e");
      throw Exception('Server returned an unexpected response. Please try again.');
    } catch (e) {
      if (_isLoggingOut) throw Exception('Session expired');
      // Only logout for genuine auth failures (4xx responses).
      // Those are already handled in the statusCode check above and throw
      // with a message that has been added to _authErrorController.
      // Any exception reaching here that is NOT "Session expired" is an
      // unexpected error — do NOT force logout for it.
      throw Exception('Refresh token failed: ${e.toString()}');
    }
  }

  // Check if user is authenticated and has student role
  Future<bool> isStudentAuthenticated() async {
    final isAuth = await isAuthenticated();
    if (!isAuth) return false;

    // Reload user from local storage to be sure
    final user = await getUser();
    if (user == null) return false;

    // Only allow students to access the student app
    return user.role.toLowerCase() == 'student';
  }

  // Signup
  Future<AuthResponse> signup({
    required String email,
    required String password,
    required String role,
    String? phone,
  }) async {
    _isLoggingOut = false; // Reset logout lock
    try {
      final response = await _httpClient.post(
        Uri.parse(ApiConfig.signupEndpoint),
        headers: _baseHeaders,
        body: jsonEncode({
          'email': email,
          'password': password,
          'role': role,
          if (phone != null && phone.isNotEmpty) 'phone': phone,
        }),
      );

      final responseData = jsonDecode(response.body) as Map<String, dynamic>;

      if (response.statusCode >= 200 && response.statusCode < 300) {
        final authResponse = AuthResponse.fromJson(responseData);

        // Store tokens and user data
        await setToken(authResponse.session.accessToken);
        await setRefreshToken(authResponse.session.refreshToken);
        await setTokenExpiry(authResponse.session.expiresAt);
        await setUser(authResponse.user);

        return authResponse;
      } else {
        final error = ApiError.fromJson(responseData);
        throw Exception(error.message);
      }
    } catch (e) {
      if (e is Exception) {
        rethrow;
      }
      throw Exception('Signup failed: ${e.toString()}');
    }
  }

  // Student Signup with verification documents
  ///
  /// Returns the signup response data on success
  /// Throws custom exceptions on error (ValidationException, ConflictException, etc.)
  Future<StudentSignupResponse> studentSignup({
    required String firstName,
    required String lastName,
    required String email,
    required String password,
    String? phone,
    required String university,
    required String cnic,
    required String dateOfBirth,
    required String studentIdCardFrontUrl,
    required String studentIdCardBackUrl,
    required String cnicFrontImageUrl,
    required String cnicBackImageUrl,
    required String selfieImageUrl,
  }) async {
    _isLoggingOut = false; // Reset logout lock
    try {
      // Prepare request body
      final requestBody = {
        'firstName': firstName,
        'lastName': lastName,
        'email': email,
        'password': password,
        'phone': phone,
        'university': university,
        'cnic': cnic,
        'dateOfBirth': dateOfBirth,
        'studentIdCardFrontUrl': studentIdCardFrontUrl,
        'studentIdCardBackUrl': studentIdCardBackUrl,
        'cnicFrontImageUrl': cnicFrontImageUrl,
        'cnicBackImageUrl': cnicBackImageUrl,
        'selfieImageUrl': selfieImageUrl,
      };

      // Make POST request
      final response = await _httpClient.post(
        Uri.parse(ApiConfig.studentSignupEndpoint),
        headers: _baseHeaders,
        body: jsonEncode(requestBody),
      );

      // Parse response
      final responseData = jsonDecode(response.body) as Map<String, dynamic>;

      // Check for success
      if (response.statusCode >= 200 && response.statusCode < 300) {
        return StudentSignupResponse.fromJson(responseData);
      } else {
        // Handle error response
        throw _handleStudentSignupError(response.statusCode, responseData);
      }
    } on http.ClientException {
      throw Exception('Network error. Please check your internet connection.');
    } catch (e) {
      if (e is ValidationException ||
          e is ConflictException ||
          e is UnprocessableEntityException ||
          e is ServerException) {
        rethrow;
      }
      throw Exception('Student signup failed: ${e.toString()}');
    }
  }

  /// Handle API error responses for student signup
  Exception _handleStudentSignupError(
      int statusCode, Map<String, dynamic> errorData) {
    final message = errorData['message'];
    String errorMessage;

    // Handle array of validation messages
    if (message is List) {
      errorMessage = message.join(', ');
    } else if (message is String) {
      errorMessage = message;
    } else {
      errorMessage = 'An error occurred';
    }

    switch (statusCode) {
      case 400:
        return ValidationException(errorMessage);
      case 409:
        return ConflictException(errorMessage);
      case 422:
        return UnprocessableEntityException(errorMessage);
      case 500:
        return ServerException(errorMessage);
      default:
        return Exception(errorMessage);
    }
  }

  // Login
  Future<AuthResponse> login({
    required String email,
    required String password,
  }) async {
    _isLoggingOut = false; // Reset logout lock
    try {
      final response = await _httpClient.post(
        Uri.parse(ApiConfig.loginEndpoint),
        headers: _baseHeaders,
        body: jsonEncode({
          'email': email,
          'password': password,
        }),
      );

      final responseData = jsonDecode(response.body) as Map<String, dynamic>;

      if (response.statusCode >= 200 && response.statusCode < 300) {
        final authResponse = AuthResponse.fromJson(responseData);

        // Store tokens and user data
        await setToken(authResponse.session.accessToken);
        await setRefreshToken(authResponse.session.refreshToken);
        await setTokenExpiry(authResponse.session.expiresAt);
        await setUser(authResponse.user);

        // Register FCM token with the backend so personal push notifications work
        // Fire-and-forget: don't block login if this fails
        _registerFcmToken(authResponse.session.accessToken);

        return authResponse;
      } else {
        final error = ApiError.fromJson(responseData);
        throw Exception(error.message);
      }
    } catch (e) {
      if (e is Exception) {
        rethrow;
      }
      throw Exception('Login failed: ${e.toString()}');
    }
  }

  /// Get the device FCM token and send it to the backend.
  /// Called after login and whenever the token is refreshed by Firebase.
  Future<void> _registerFcmToken(String accessToken) async {
    try {
      // On iOS this requires an APNS token — will be null on Simulator
      final String? fcmToken = await NotificationHandlerService().getToken();
      if (fcmToken == null) {
        print('FCM: No token available (Simulator or permissions denied), skipping registration.');
        return;
      }

      final response = await _httpClient.patch(
        Uri.parse(ApiConfig.updateFcmTokenEndpoint),
        headers: {
          ..._baseHeaders,
          'Authorization': 'Bearer $accessToken',
        },
        body: jsonEncode({'token': fcmToken}),
      );

      if (response.statusCode >= 200 && response.statusCode < 300) {
        print('FCM: Token registered with backend successfully.');
      } else {
        print('FCM: Failed to register token — ${response.statusCode}: ${response.body}');
      }
    } catch (e) {
      print('FCM: Error registering token: $e');
    }
  }

  // Get current user profile
  Future<ProfileResponse> getProfile() async {
    final token = await getToken();
    if (token == null) {
      throw Exception('No token found. Please login again.');
    }

    try {
      final response = await _httpClient.get(
        Uri.parse(ApiConfig.profileEndpoint),
        headers: {
          ..._baseHeaders,
          'Authorization': 'Bearer $token',
        },
      );

      final responseData = jsonDecode(response.body) as Map<String, dynamic>;

      if (response.statusCode >= 200 && response.statusCode < 300) {
        final profileResponse = ProfileResponse.fromJson(responseData);

        // Update stored user data
        await setUser(profileResponse.user);

        return profileResponse;
      } else {
        final error = ApiError.fromJson(responseData);
        throw Exception(error.message);
      }
    } catch (e) {
      if (e is Exception) {
        rethrow;
      }
      throw Exception('Failed to get profile: ${e.toString()}');
    }
  }

  // Forgot Password
  Future<void> forgotPassword(String email) async {
    try {
      final response = await _httpClient.post(
        Uri.parse(ApiConfig.forgotPasswordEndpoint),
        headers: _baseHeaders,
        body: jsonEncode({
          'email': email,
        }),
      );

      final responseData = jsonDecode(response.body) as Map<String, dynamic>;

      if (response.statusCode == 200) {
        // Success - password reset email sent
        // The API returns success even if email doesn't exist (for security)
        return;
      } else {
        // Handle error response
        String errorMessage = 'Failed to send password reset email';

        if (responseData.containsKey('message')) {
          final message = responseData['message'];
          if (message is List) {
            errorMessage = message.join(', ');
          } else if (message is String) {
            errorMessage = message;
          }
        }

        throw Exception(errorMessage);
      }
    } catch (e) {
      if (e is Exception) {
        rethrow;
      }
      throw Exception('Network error: ${e.toString()}');
    }
  }

  // [NEW] Update Profile Picture Endpoint
  Future<void> updateProfilePicture(String imageUrl) async {
    final token = await getToken();
    if (token == null) {
      throw Exception('No token found. Please login again.');
    }

    try {
      final response = await _httpClient.patch(
        // Ensure this matches your backend route
        Uri.parse('${ApiConfig.baseUrl}/auth/student/profile-picture'),
        headers: {
          ..._baseHeaders,
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({'imageUrl': imageUrl}),
      );

      if (response.statusCode != 200) {
        final responseData = jsonDecode(response.body);
        throw Exception(
            responseData['message'] ?? 'Failed to update profile picture');
      }

      // Optionally force a profile refresh here
      await getProfile();
    } catch (e) {
      throw Exception('Network error: $e');
    }
  }

  // Change Password
  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    final token = await getToken();
    if (token == null) {
      throw Exception('No token found. Please login again.');
    }

    try {
      final response = await _httpClient.post(
        Uri.parse(ApiConfig.changePasswordEndpoint),
        headers: {
          ..._baseHeaders,
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'currentPassword': currentPassword,
          'newPassword': newPassword,
        }),
      );

      final responseData = jsonDecode(response.body) as Map<String, dynamic>;

      if (response.statusCode == 200) {
        // Password changed successfully
        // Note: The existing token remains valid, no need to update it
        return;
      } else {
        // Handle error responses
        String errorMessage = 'Failed to change password';

        if (responseData.containsKey('message')) {
          final message = responseData['message'];
          if (message is List) {
            errorMessage = message.join(', ');
          } else if (message is String) {
            errorMessage = message;
          }
        }

        throw Exception(errorMessage);
      }
    } catch (e) {
      if (e is Exception) {
        rethrow;
      }
      throw Exception('Change password failed: ${e.toString()}');
    }
  }

  // Logout
  Future<void> logout() async {
    // [NEW] 1. Check if already logging out
    if (_isLoggingOut) return;

    // [NEW] 2. Set lock
    _isLoggingOut = true;

    try {
      final token = await getToken();

      if (token != null) {
        try {
          await _httpClient.post(
            Uri.parse(ApiConfig.logoutEndpoint),
            headers: {
              ..._baseHeaders,
              'Authorization': 'Bearer $token',
            },
          );
        } catch (e) {
          // Ignore network errors during logout
        }
      }

      // Always remove tokens locally
      await removeToken();

      // Navigation after logout is handled by the calling UI layer (ProfileScreen),
      // NOT here — so guests can continue browsing on the home screen.
    } finally {
      _isLoggingOut = false; // Reset so a fresh logout can run after re-login
    }
  }
  // --- STANDARDIZED API METHODS ---

  Map<String, String> _authHeaders(String token) => {
        ..._baseHeaders,
        'Authorization': 'Bearer $token',
      };

  /// Makes a GET request that works for both guests and authenticated users.
  /// If a valid token exists it is included (so the server can personalise the
  /// response), otherwise the request is sent without an Authorization header.
  /// Use this for any endpoint that should be publicly accessible.
  Future<http.Response> publicGet(String url) async {
    final token = await getToken().catchError((_) => null);
    final uri = Uri.parse(url);
    final headers = (token != null) ? _authHeaders(token) : Map<String, String>.from(_baseHeaders);
    return _httpClient.get(uri, headers: headers);
  }

  // Helper method to handle authenticated GET requests with auto-refresh retry
  Future<http.Response> authenticatedGet(String url) async {
    // 0. Bail out immediately if a logout is already in progress
    if (_isLoggingOut) throw Exception('Session expired');

    // 1. Get current token — served from memory cache on most calls
    String? token = await getToken();

    if (_isLoggingOut) throw Exception('Session expired');

    if (token == null) {
      throw Exception('No authentication token found. Please login.');
    }

    final uri = Uri.parse(url);

    // 2. First attempt — uses persistent client (no TLS re-handshake)
    var response = await _httpClient.get(uri, headers: _authHeaders(token));

    // 3. On 401/403 refresh once and retry
    if (response.statusCode == 401 || response.statusCode == 403) {
      if (_isLoggingOut) throw Exception('Session expired');

      print(
          "Got ${response.statusCode}. Attempting to refresh token and retry...");
      try {
        await refreshToken();
        token = await getToken();

        if (token != null) {
          response = await _httpClient.get(uri, headers: _authHeaders(token));

          if (response.statusCode == 401 || response.statusCode == 403) {
            final errorMessage = _extractErrorMessage(response);
            _authErrorController.add(errorMessage);
            await logout();
            throw Exception(errorMessage);
          }
        }
      } catch (e) {
        if (e.toString().contains("Session expired")) rethrow;
        rethrow; // surface the real error (e.g. deactivation message)
      }
    }

    return response;
  }

  // Helper method to handle authenticated POST requests
  Future<http.Response> authenticatedPost(String url, {Object? body}) async {
    // 0. Bail out immediately if a logout is already in progress
    if (_isLoggingOut) throw Exception('Session expired');

    String? token = await getToken();

    if (token == null) throw Exception('No authentication token found.');

    final uri = Uri.parse(url);

    var response = await _httpClient.post(
      uri,
      headers: _authHeaders(token),
      body: body != null ? jsonEncode(body) : null,
    );

    if (response.statusCode == 401 || response.statusCode == 403) {
      if (_isLoggingOut) throw Exception('Session expired');

      print(
          "Got ${response.statusCode} (POST). Attempting to refresh...");
      try {
        await refreshToken();
        token = await getToken();

        if (token != null) {
          response = await _httpClient.post(
            uri,
            headers: _authHeaders(token),
            body: body != null ? jsonEncode(body) : null,
          );

          if (response.statusCode == 401 || response.statusCode == 403) {
            final errorMessage = _extractErrorMessage(response);
            _authErrorController.add(errorMessage);
            await logout();
            throw Exception(errorMessage);
          }
        }
      } catch (e) {
        if (e.toString().contains("Session expired")) rethrow;
        rethrow; // surface the real error (e.g. deactivation message)
      }
    }

    return response;
  }

  // Helper to extract error message from API response
  String _extractErrorMessage(http.Response response) {
    try {
      final responseData = jsonDecode(response.body) as Map<String, dynamic>;

      if (responseData.containsKey('message')) {
        final message = responseData['message'];
        if (message is String) return message;
        if (message is List) return message.join(', ');
      }

      if (responseData.containsKey('error')) {
        return responseData['error'].toString();
      }

      return 'Your account has been deactivated. Please contact support.';
    } catch (e) {
      return 'Your account has been deactivated. Please contact support.';
    }
  }

  // Clean up resources
  void dispose() {
    _httpClient.close();
    _authErrorController.close();
  }
}

// Singleton instance
final authService = AuthService();
