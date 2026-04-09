import 'dart:io';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../config/supabase_config.dart';
import 'auth_service.dart'; // [Import Auth Service]
import 'package:flutter/foundation.dart'; // For debugPrint
class SupabaseStorageService {
  final SupabaseClient _supabase = Supabase.instance.client;

  /// Upload student ID image to Supabase Storage
  /// Returns the public URL of the uploaded image
  Future<String> uploadStudentIdImage(File imageFile, String userId) async {
    try {
      final String filePath = SupabaseConfig.getStudentIdPath(userId);
      
      // Upload file to Supabase Storage
      await _supabase.storage
          .from(SupabaseConfig.studentKycBucket)
          .upload(filePath, imageFile, fileOptions: const FileOptions(
            cacheControl: '3600',
            upsert: false,
          ));

      // Get public URL
      final String publicUrl = _supabase.storage
          .from(SupabaseConfig.studentKycBucket)
          .getPublicUrl(filePath);

      return publicUrl;
    } catch (e) {
      throw Exception('Failed to upload student ID image: $e');
    }
  }

  /// Upload student ID back image to Supabase Storage
  /// Returns the public URL of the uploaded image
  Future<String> uploadStudentIdBackImage(File imageFile, String userId) async {
    try {
      final String filePath = SupabaseConfig.getStudentIdBackPath(userId);
      
      // Upload file to Supabase Storage
      await _supabase.storage
          .from(SupabaseConfig.studentKycBucket)
          .upload(filePath, imageFile, fileOptions: const FileOptions(
            cacheControl: '3600',
            upsert: false,
          ));

      // Get public URL
      final String publicUrl = _supabase.storage
          .from(SupabaseConfig.studentKycBucket)
          .getPublicUrl(filePath);

      return publicUrl;
    } catch (e) {
      throw Exception('Failed to upload student ID back image: $e');
    }
  }

  /// Upload selfie image to Supabase Storage
  /// Returns the public URL of the uploaded image
  Future<String> uploadSelfieImage(File imageFile, String userId) async {
    try {
      final String filePath = SupabaseConfig.getSelfiePath(userId);
      
      // Upload file to Supabase Storage
      await _supabase.storage
          .from(SupabaseConfig.studentKycBucket)
          .upload(filePath, imageFile, fileOptions: const FileOptions(
            cacheControl: '3600',
            upsert: false,
          ));

      // Get public URL
      final String publicUrl = _supabase.storage
          .from(SupabaseConfig.studentKycBucket)
          .getPublicUrl(filePath);

      return publicUrl;
    } catch (e) {
      throw Exception('Failed to upload selfie image: $e');
    }
  }

  /// Upload CNIC front image to Supabase Storage
  /// Returns the public URL of the uploaded image
  Future<String> uploadCnicFrontImage(File imageFile, String userId) async {
    try {
      final String filePath = SupabaseConfig.getCnicFrontPath(userId);
      
      // Upload file to Supabase Storage
      await _supabase.storage
          .from(SupabaseConfig.studentKycBucket)
          .upload(filePath, imageFile, fileOptions: const FileOptions(
            cacheControl: '3600',
            upsert: false,
          ));

      // Get public URL
      final String publicUrl = _supabase.storage
          .from(SupabaseConfig.studentKycBucket)
          .getPublicUrl(filePath);

      return publicUrl;
    } catch (e) {
      throw Exception('Failed to upload CNIC front image: $e');
    }
  }

  /// Upload CNIC back image to Supabase Storage
  /// Returns the public URL of the uploaded image
  Future<String> uploadCnicBackImage(File imageFile, String userId) async {
    try {
      final String filePath = SupabaseConfig.getCnicBackPath(userId);
      
      // Upload file to Supabase Storage
      await _supabase.storage
          .from(SupabaseConfig.studentKycBucket)
          .upload(filePath, imageFile, fileOptions: const FileOptions(
            cacheControl: '3600',
            upsert: false,
          ));

      // Get public URL
      final String publicUrl = _supabase.storage
          .from(SupabaseConfig.studentKycBucket)
          .getPublicUrl(filePath);

      return publicUrl;
    } catch (e) {
      throw Exception('Failed to upload CNIC back image: $e');
    }
  }

  /// Upload all KYC images and return their URLs
  /// Returns a map with 'studentIdUrl', 'studentIdBackUrl', 'cnicFrontUrl', 'cnicBackUrl', and 'selfieUrl' keys
  Future<Map<String, String>> uploadKycImages({
    required File studentIdImage,
    required File studentIdBackImage,
    required File cnicFrontImage,
    required File cnicBackImage,
    required File selfieImage,
    required String userId,
  }) async {
    try {
      return {
        // Uploading one-by-one is slower but much more stable on Android
        // networks/devices than 5 concurrent large uploads.
        'studentIdUrl': await uploadStudentIdImage(studentIdImage, userId),
        'studentIdBackUrl':
            await uploadStudentIdBackImage(studentIdBackImage, userId),
        'cnicFrontUrl': await uploadCnicFrontImage(cnicFrontImage, userId),
        'cnicBackUrl': await uploadCnicBackImage(cnicBackImage, userId),
        'selfieUrl': await uploadSelfieImage(selfieImage, userId),
      };
    } catch (e) {
      throw Exception('Failed to upload KYC images: $e');
    }
  }

  // [FIXED] Upload Profile Picture
    Future<String> uploadProfilePicture(File imageFile, String userId) async {
      try {
        final String timestamp = DateTime.now().millisecondsSinceEpoch.toString();
        final String filePath = '$userId/profile_$timestamp.jpg';
        
        // 1. Get the REFRESH token (Correct token for setSession)
        final refreshToken = await authService.getRefreshToken();
        
        if (refreshToken != null) {
          try {
            // This logs the Flutter Supabase client in so RLS policies pass
            await _supabase.auth.setSession(refreshToken);
          } catch (authError) {
            // If session sync fails, log it but don't crash the app.
            // The upload might still fail if RLS blocks it, but at least the app won't close.
            debugPrint("Supabase session sync warning: $authError");
          }
        } else {
          debugPrint("No refresh token found. Uploading as anonymous/current session.");
        }

        // 2. Upload to 'avatars' bucket
        await _supabase.storage.from('avatars').upload(
          filePath, 
          imageFile,
          fileOptions: const FileOptions(cacheControl: '3600', upsert: true),
        );

        // 3. Get Public URL
        final String publicUrl = _supabase.storage.from('avatars').getPublicUrl(filePath);
        return publicUrl;
      } catch (e) {
        throw Exception('Failed to upload profile picture: $e');
      }
    }
  


  /// Delete an image from Supabase Storage
  Future<void> deleteImage(String filePath) async {
    try {
      await _supabase.storage
          .from(SupabaseConfig.studentKycBucket)
          .remove([filePath]);
    } catch (e) {
      throw Exception('Failed to delete image: $e');
    }
  }
}

