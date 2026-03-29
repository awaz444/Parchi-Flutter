// Auth Models for API responses

class User {
  final String id;
  final String email;
  final String role;
  final bool isActive;
  
  // [NEW] Added phone field
  final String? phone;
  
  // Student specific fields
  final String? firstName;
  final String? lastName;
  final String? parchiId;
  final String? university;
  final String? profilePicture;
  final bool isFoundersClub; // [NEW]
  final String? verificationStatus; // [NEW]
  final bool hasUnreadNotifications; // [NEW]

  User({
    required this.id,
    required this.email,
    required this.role,
    required this.isActive,
    this.phone, 
    this.firstName,
    this.lastName,
    this.parchiId,
    this.university,
    this.profilePicture, 
    this.isFoundersClub = false, // [NEW] Default to false
    this.verificationStatus, // [NEW]
    this.hasUnreadNotifications = false, // [NEW]
  });

  factory User.fromJson(Map<String, dynamic> json) {
    final studentData = json['student'];

    return User(
      id: json['id'] as String,
      email: json['email'] as String,
      role: json['role'] as String,
      isActive: json['is_active'] as bool? ?? false,
      
      // [NEW] Map the phone number from the root user object
      phone: json['phone'] as String?, 
      
      firstName: studentData != null 
          ? studentData['first_name'] 
          : json['first_name'] ?? json['firstName'],
      
      lastName: studentData != null 
          ? studentData['last_name'] 
          : json['last_name'] ?? json['lastName'],
      
      parchiId: studentData != null 
          ? studentData['parchi_id'] 
          : json['parchi_id'] ?? json['parchiId'],
          
      university: studentData != null 
          ? studentData['university'] 
          : json['university'],
    
    // [FIX] Add this block to read the profile picture from backend response
      profilePicture: studentData != null 
          ? studentData['profile_picture'] 
          : json['profile_picture'] ?? json['profilePicture'],

      // [NEW] Parse is_founders_club
      isFoundersClub: studentData != null
          ? (studentData['is_founders_club'] as bool? ?? false)
          : (json['is_founders_club'] as bool?) ?? (json['isFoundersClub'] as bool? ?? false),

      // [NEW] Parse verification_status
      verificationStatus: studentData != null
          ? (studentData['verification_status'] as String?)
          : (json['verification_status'] as String?) ?? (json['verificationStatus'] as String?), // Check snake_case first from root
      
      // [NEW] Parse hasUnreadNotifications
      hasUnreadNotifications: json['hasUnreadNotifications'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'email': email,
      'role': role,
      'is_active': isActive,
      'phone': phone, 
      'firstName': firstName,
      'lastName': lastName,
      'parchiId': parchiId,
      'university': university,
      'university': university,
      'profilePicture': profilePicture, 
      'isFoundersClub': isFoundersClub, // [NEW]
      'verificationStatus': verificationStatus, // [NEW]
      'hasUnreadNotifications': hasUnreadNotifications, // [NEW]
    };
  }
}

class Session {
  final String accessToken;
  final String refreshToken;
  final int expiresAt;
  final int expiresIn;
  final String tokenType;
  final User? user;

  Session({
    required this.accessToken,
    required this.refreshToken,
    required this.expiresAt,
    required this.expiresIn,
    required this.tokenType,
    this.user,
  });

  factory Session.fromJson(Map<String, dynamic> json) {
    // Robustly handle expires_at. If not present, calculate from expires_in
    int expiresAt;
    if (json['expires_at'] != null) {
      expiresAt = json['expires_at'] as int;
    } else {
       // expires_in is usually in seconds. Current time + seconds
       final expiresIn = json['expires_in'] as int? ?? 3600;
       expiresAt = (DateTime.now().millisecondsSinceEpoch ~/ 1000) + expiresIn;
    }

    // Supabase nests a GoTrue user under session.user (`aud`, `identities`, …).
    // Our API user lives only on data.user — parse session.user only if it looks
    // like the app schema (no Supabase `aud`).
    final rawSessionUser = json['user'];
    User? sessionUser;
    if (rawSessionUser is Map<String, dynamic> &&
        !rawSessionUser.containsKey('aud')) {
      sessionUser = User.fromJson(rawSessionUser);
    }

    return Session(
      accessToken: json['access_token'] as String,
      refreshToken: json['refresh_token'] as String,
      expiresAt: expiresAt,
      expiresIn: json['expires_in'] as int? ?? 3600,
      tokenType: json['token_type'] as String? ?? 'bearer',
      user: sessionUser,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'access_token': accessToken,
      'refresh_token': refreshToken,
      'expires_at': expiresAt,
      'expires_in': expiresIn,
      'token_type': tokenType,
      if (user != null) 'user': user!.toJson(),
    };
  }
}

class AuthResponse {
  final User user;
  final Session session;
  final int status;
  final String message;

  AuthResponse({
    required this.user,
    required this.session,
    required this.status,
    required this.message,
  });

  factory AuthResponse.fromJson(Map<String, dynamic> json) {
    final data = json['data'] as Map<String, dynamic>;
    return AuthResponse(
      user: User.fromJson(data['user'] as Map<String, dynamic>),
      session: Session.fromJson(data['session'] as Map<String, dynamic>),
      status: json['status'] as int? ?? 200,
      message: json['message'] as String? ?? '',
    );
  }
}

class ProfileResponse {
  final User user;
  final int status;
  final String message;

  ProfileResponse({
    required this.user,
    required this.status,
    required this.message,
  });

  factory ProfileResponse.fromJson(Map<String, dynamic> json) {
    // Handle the wrapper if it exists, or direct data
    final userData = json['data'] ?? json;
    
    return ProfileResponse(
      user: User.fromJson(userData as Map<String, dynamic>),
      status: json['status'] as int? ?? 200,
      message: json['message'] as String? ?? '',
    );
  }
}

class ApiError {
  final int statusCode;
  final String message;
  final String error;

  ApiError({
    required this.statusCode,
    required this.message,
    required this.error,
  });

  factory ApiError.fromJson(Map<String, dynamic> json) {
    return ApiError(
      statusCode: json['statusCode'] as int? ?? 500,
      message: json['message'] as String? ?? 'An error occurred',
      error: json['error'] as String? ?? 'Internal Server Error',
    );
  }
}

// Student Signup Response Model
class StudentSignupResponse {
  final String id;
  final String email;
  final String firstName;
  final String lastName;
  final String university;
  final String parchiId;
  final String verificationStatus;
  final DateTime createdAt;
  final int status;
  final String message;

  StudentSignupResponse({
    required this.id,
    required this.email,
    required this.firstName,
    required this.lastName,
    required this.university,
    required this.parchiId,
    required this.verificationStatus,
    required this.createdAt,
    required this.status,
    required this.message,
  });

  factory StudentSignupResponse.fromJson(Map<String, dynamic> json) {
    final data = json['data'] as Map<String, dynamic>;
    return StudentSignupResponse(
      id: data['id'] as String,
      email: data['email'] as String,
      firstName: data['firstName'] as String,
      lastName: data['lastName'] as String,
      university: data['university'] as String,
      parchiId: data['parchiId'] as String,
      verificationStatus: data['verificationStatus'] as String,
      createdAt: DateTime.parse(data['createdAt'] as String),
      status: json['status'] as int? ?? 201,
      message: json['message'] as String? ?? '',
    );
  }
}

// Custom Exception Classes for Student Signup
class ValidationException implements Exception {
  final String message;
  ValidationException(this.message);
  
  @override
  String toString() => message;
}

class ConflictException implements Exception {
  final String message;
  ConflictException(this.message);
  
  @override
  String toString() => message;
}

class UnprocessableEntityException implements Exception {
  final String message;
  UnprocessableEntityException(this.message);
  
  @override
  String toString() => message;
}

class ServerException implements Exception {
  final String message;
  ServerException(this.message);
  
  @override
  String toString() => message;
}