import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../utils/colours.dart';
import '../../../services/supabase_storage_service.dart';
import '../../../services/auth_service.dart';
import '../../../widgets/common/spinning_loader.dart';
import '../../../providers/user_provider.dart';


class ProfilePictureUploadSheet extends ConsumerStatefulWidget {
  /* 
   * [UX IMPROVEMENT]: Callbacks to notify parent (ProfileScreen) about upload state.
   * This allows the "Focused Avatar" in the parent to show a loader.
   */
  final VoidCallback onClose; // [RESTORED]
  final ValueChanged<bool>? onLoadingStateChanged; // [RESTORED]
  final ValueChanged<File?>? onImageSelected; // [NEW]

  const ProfilePictureUploadSheet({
    super.key, 
    required this.onClose,
    this.onLoadingStateChanged,
    this.onImageSelected, // [NEW]
  });

  @override
  ConsumerState<ProfilePictureUploadSheet> createState() => _ProfilePictureUploadSheetState();
}

class _ProfilePictureUploadSheetState extends ConsumerState<ProfilePictureUploadSheet> {
  File? _selectedImage;
  bool _isUploading = false;
  final ImagePicker _picker = ImagePicker();
  final SupabaseStorageService _storageService = SupabaseStorageService();

  Future<void> _pickImage(ImageSource source) async {
    try {
      final XFile? picked = await _picker.pickImage(source: source, imageQuality: 70);
      if (picked != null) {
        setState(() => _selectedImage = File(picked.path));
        widget.onImageSelected?.call(_selectedImage); // [NEW] Notify Parent
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
    }
  }

  Future<void> _handleUpload() async {
    if (_selectedImage == null) return;

    setState(() => _isUploading = true);
    widget.onLoadingStateChanged?.call(true);

    try {
      final user = ref.read(userProfileProvider).value;
      if (user == null) throw Exception("User not found");

      final String publicUrl = await _storageService.uploadProfilePicture(_selectedImage!, user.id);
      await authService.updateProfilePicture(publicUrl);
      await ref.refresh(userProfileProvider.future);

      if (mounted) {
        widget.onClose();
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text("Profile updated!", style: TextStyle(color: AppColors.primary)),
          backgroundColor: Colors.white,
          behavior: SnackBarBehavior.floating,
        ));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text("Upload failed: $e"),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ));
      }
    } finally {
      if (mounted) {
        setState(() => _isUploading = false);
        widget.onLoadingStateChanged?.call(false);
      }
    }
  }

  Future<void> _handleRemovePhoto() async {
    final user = ref.read(userProfileProvider).value;
    if (user?.profilePicture == null) return; // No photo to remove

    setState(() => _isUploading = true);
    widget.onLoadingStateChanged?.call(true);

    try {
      // Update backend with empty string to clear the picture
      await authService.updateProfilePicture('');
      await ref.refresh(userProfileProvider.future);

      if (mounted) {
        widget.onClose();
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text("Photo removed", style: TextStyle(color: AppColors.primary)),
          backgroundColor: Colors.white,
          behavior: SnackBarBehavior.floating,
        ));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text("Failed to remove photo: $e"),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ));
      }
    } finally {
      if (mounted) {
        setState(() => _isUploading = false);
        widget.onLoadingStateChanged?.call(false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
      child: Padding(
        // Add bottom safe area padding for Android gesture navigation bar
        padding: EdgeInsets.fromLTRB(
          24,
          16,
          24,
          40 + MediaQuery.of(context).padding.bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle bar
            Center(
              child: Container(
                width: 40, height: 4, margin: const EdgeInsets.only(bottom: 20),
                decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2)),
              ),
            ),

            const Text(
              "Change Profile Photo",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
            ),
            const SizedBox(height: 30),

            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                Consumer(builder: (context, ref, _) {
                  final user = ref.watch(userProfileProvider).value;
                  final hasPhoto = user?.profilePicture != null && user!.profilePicture!.isNotEmpty;
                  return _buildOptionButton(
                    Icons.delete_outline_rounded,
                    "Remove",
                    hasPhoto ? _handleRemovePhoto : null,
                    destructive: true,
                    disabled: !hasPhoto,
                  );
                }),
                _buildOptionButton(Icons.camera_alt_rounded, "Retake", () => _pickImage(ImageSource.camera)),
                _buildOptionButton(Icons.photo_library_rounded, "Upload", () => _pickImage(ImageSource.gallery)),
              ],
            ),

            if (_selectedImage != null) ...[
              const SizedBox(height: 30),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _isUploading ? null : _handleUpload,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary, // Keep Blue
                    disabledBackgroundColor: AppColors.primary, // Keep Blue when loading
                    foregroundColor: Colors.white,
                  ),
                  child: _isUploading 
                      ? const SpinningLoader(size: 20, color: Colors.white)
                      : const Text("Save Photo"),
                ),
              ),
            ]
          ],
        ),
      ),
    );
  }

  Widget _buildOptionButton(
    IconData icon,
    String label,
    VoidCallback? onTap, {
    bool destructive = false,
    bool disabled = false,
  }) {
    final isDisabled = _isUploading || disabled || onTap == null;
    final color = destructive ? AppColors.error : AppColors.textSecondary;
    return InkWell(
      onTap: isDisabled ? null : onTap,
      borderRadius: BorderRadius.circular(16),
      child: Opacity(
        opacity: (disabled || _isUploading) ? 0.35 : 1.0,
        child: Container(
          width: 90,
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            color: destructive ? AppColors.error.withOpacity(0.06) : Colors.grey.shade50,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: destructive ? AppColors.error.withOpacity(0.2) : Colors.grey.shade200,
            ),
          ),
          child: Column(children: [
            Icon(icon, size: 26, color: color),
            const SizedBox(height: 6),
            Text(label, style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w500)),
          ]),
        ),
      ),
    );
  }
}