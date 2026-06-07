import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../utils/colours.dart';
import '../../../services/selfie_change_service.dart';
import '../../../widgets/common/spinning_loader.dart';
import '../../../utils/toast_utils.dart';

class SelfieChangeUploadSheet extends ConsumerStatefulWidget {
  final VoidCallback onClose;
  final ValueChanged<bool>? onLoadingStateChanged;
  final VoidCallback? onSubmitted;

  const SelfieChangeUploadSheet({
    super.key,
    required this.onClose,
    this.onLoadingStateChanged,
    this.onSubmitted,
  });

  @override
  ConsumerState<SelfieChangeUploadSheet> createState() =>
      _SelfieChangeUploadSheetState();
}

class _SelfieChangeUploadSheetState extends ConsumerState<SelfieChangeUploadSheet> {
  File? _selectedImage;
  bool _isUploading = false;
  final ImagePicker _picker = ImagePicker();

  Future<void> _pickImage(ImageSource source) async {
    try {
      final picked = await _picker.pickImage(source: source, imageQuality: 80);
      if (picked != null) {
        setState(() => _selectedImage = File(picked.path));
      }
    } catch (e) {
      if (mounted) ToastUtils.handleApiError(context, e);
    }
  }

  Future<void> _handleSubmit() async {
    if (_selectedImage == null) return;

    setState(() => _isUploading = true);
    widget.onLoadingStateChanged?.call(true);

    try {
      await selfieChangeService.submitRequest(_selectedImage!);
      widget.onSubmitted?.call();
      if (mounted) {
        widget.onClose();
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text(
            "Selfie change request submitted for review",
            style: TextStyle(color: AppColors.primary),
          ),
          backgroundColor: Colors.white,
          behavior: SnackBarBehavior.floating,
        ));
      }
    } catch (e) {
      if (mounted) ToastUtils.handleApiError(context, e);
    } finally {
      if (mounted) {
        setState(() => _isUploading = false);
        widget.onLoadingStateChanged?.call(false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.surfaceVariant,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            "Update Verification Selfie",
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            "Upload a new selfie for admin review. Your current verification selfie stays active until approved.",
            style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 20),
          if (_selectedImage != null)
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Image.file(_selectedImage!, height: 180, fit: BoxFit.cover),
            ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _isUploading ? null : () => _pickImage(ImageSource.camera),
                  icon: const Icon(Icons.camera_alt_outlined),
                  label: const Text("Camera"),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _isUploading ? null : () => _pickImage(ImageSource.gallery),
                  icon: const Icon(Icons.photo_library_outlined),
                  label: const Text("Gallery"),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: _selectedImage == null || _isUploading ? null : _handleSubmit,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: _isUploading
                ? const SpinningLoader(size: 20, color: Colors.white)
                : const Text("Submit for Review", style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
}
