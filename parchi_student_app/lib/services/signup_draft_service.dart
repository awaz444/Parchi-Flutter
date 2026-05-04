import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Persists signup form progress locally so users can resume if they quit.
/// Step-1 text fields are saved to SharedPreferences on every change.
/// The password is stored in FlutterSecureStorage for safety.
/// Step-2 image paths are saved after each image is picked.
/// All data is cleared once registration succeeds.
class SignupDraftService {
  static const String _prefix = 'signup_draft_';
  static const String _keyFirstName = '${_prefix}first_name';
  static const String _keyLastName = '${_prefix}last_name';
  static const String _keyEmail = '${_prefix}email';
  static const String _keyPhone = '${_prefix}phone';
  static const String _keyUniversity = '${_prefix}university';
  static const String _keyGrade = '${_prefix}grade';
  static const String _keyDob = '${_prefix}dob';
  static const String _keyStudentIdFront = '${_prefix}student_id_front';
  static const String _keyStudentIdBack = '${_prefix}student_id_back';
  static const String _keySelfie = '${_prefix}selfie';
  static const String _keyIsStudentIdVerification =
      '${_prefix}is_student_id_verification';

  // Password lives in secure storage only
  static const String _keyPasswordSecure = 'signup_draft_password';

  final _secureStorage = const FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );

  // ---------------------------------------------------------------------------
  // Write
  // ---------------------------------------------------------------------------

  /// Saves step-1 personal-details fields. Null parameters are ignored so
  /// callers can pass only the fields that changed.
  Future<void> saveStep1({
    String? firstName,
    String? lastName,
    String? email,
    String? password,
    String? phone,
    String? university,
    String? grade,
    String? dob,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    if (firstName != null) prefs.setString(_keyFirstName, firstName);
    if (lastName != null) prefs.setString(_keyLastName, lastName);
    if (email != null) prefs.setString(_keyEmail, email);
    if (phone != null) prefs.setString(_keyPhone, phone);
    if (university != null) prefs.setString(_keyUniversity, university);
    if (grade != null) prefs.setString(_keyGrade, grade);
    if (dob != null) prefs.setString(_keyDob, dob);
    if (password != null) {
      _secureStorage.write(key: _keyPasswordSecure, value: password);
    }
  }

  /// Saves step-2 image paths. Null parameters are ignored.
  Future<void> saveStep2({
    String? studentIdFrontPath,
    String? studentIdBackPath,
    String? selfiePath,
    bool? isStudentIdVerification,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    if (studentIdFrontPath != null) {
      prefs.setString(_keyStudentIdFront, studentIdFrontPath);
    }
    if (studentIdBackPath != null) {
      prefs.setString(_keyStudentIdBack, studentIdBackPath);
    }
    if (selfiePath != null) prefs.setString(_keySelfie, selfiePath);
    if (isStudentIdVerification != null) {
      prefs.setBool(_keyIsStudentIdVerification, isStudentIdVerification);
    }
  }

  // ---------------------------------------------------------------------------
  // Read
  // ---------------------------------------------------------------------------

  Future<SignupDraft> loadDraft() async {
    final prefs = await SharedPreferences.getInstance();
    final password = await _secureStorage.read(key: _keyPasswordSecure);
    return SignupDraft(
      firstName: prefs.getString(_keyFirstName),
      lastName: prefs.getString(_keyLastName),
      email: prefs.getString(_keyEmail),
      password: password,
      phone: prefs.getString(_keyPhone),
      university: prefs.getString(_keyUniversity),
      grade: prefs.getString(_keyGrade),
      dob: prefs.getString(_keyDob),
      studentIdFrontPath: prefs.getString(_keyStudentIdFront),
      studentIdBackPath: prefs.getString(_keyStudentIdBack),
      selfiePath: prefs.getString(_keySelfie),
      isStudentIdVerification:
          prefs.getBool(_keyIsStudentIdVerification),
    );
  }

  // ---------------------------------------------------------------------------
  // Clear
  // ---------------------------------------------------------------------------

  Future<void> clearDraft() async {
    final prefs = await SharedPreferences.getInstance();
    for (final key in [
      _keyFirstName,
      _keyLastName,
      _keyEmail,
      _keyPhone,
      _keyUniversity,
      _keyGrade,
      _keyDob,
      _keyStudentIdFront,
      _keyStudentIdBack,
      _keySelfie,
      _keyIsStudentIdVerification,
    ]) {
      prefs.remove(key);
    }
    _secureStorage.delete(key: _keyPasswordSecure);
  }
}

// ---------------------------------------------------------------------------
// Data class
// ---------------------------------------------------------------------------

class SignupDraft {
  final String? firstName;
  final String? lastName;
  final String? email;
  final String? password;
  final String? phone;
  final String? university;
  final String? grade;
  final String? dob;
  final String? studentIdFrontPath;
  final String? studentIdBackPath;
  final String? selfiePath;
  final bool? isStudentIdVerification;

  const SignupDraft({
    this.firstName,
    this.lastName,
    this.email,
    this.password,
    this.phone,
    this.university,
    this.grade,
    this.dob,
    this.studentIdFrontPath,
    this.studentIdBackPath,
    this.selfiePath,
    this.isStudentIdVerification,
  });

  bool get hasStep1Data =>
      firstName != null ||
      lastName != null ||
      email != null ||
      phone != null;

  bool get hasStep2Data =>
      studentIdFrontPath != null ||
      selfiePath != null;
}

// Singleton instance used across the signup flow
final signupDraftService = SignupDraftService();
