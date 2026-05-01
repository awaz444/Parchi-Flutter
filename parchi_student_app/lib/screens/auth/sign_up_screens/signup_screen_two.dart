import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:image_picker/image_picker.dart';
import '../../../utils/colours.dart';
import '../../../utils/toast_utils.dart';
import '../../../services/auth_service.dart';
import '../../../models/auth_models.dart'; // [NEW] For ConflictException
import '../../../widgets/common/tap_to_dismiss_keyboard.dart';
import 'signup_verification_screen.dart';
import 'verification_success_screen.dart'; // [NEW]

import '../../../widgets/common/spinning_loader.dart';
import '../../../widgets/common/image_source_popup.dart'; // [NEW] Import
import '../../../services/analytics_service.dart';
import '../../../services/signup_draft_service.dart';


class SignupScreenTwo extends StatefulWidget {
  final String firstName;
  final String lastName;
  final String email;
  final String password;
  final String phone;
  final String university;
  final String educationalGrade;
  final String dateOfBirth;

  const SignupScreenTwo({
    super.key,
    required this.firstName,
    required this.lastName,
    required this.email,
    required this.password,
    required this.phone,
    required this.university,
    required this.educationalGrade,
    required this.dateOfBirth,
  });

  @override
  State<SignupScreenTwo> createState() => _SignupScreenTwoState();
}


class _SignupScreenTwoState extends State<SignupScreenTwo> {
  final ImagePicker _imagePicker = ImagePicker();
  File? _studentIdImage;
  File? _studentIdBackImage;
  File? _cnicFrontImage;
  File? _cnicBackImage;
  File? _selfieImage;
  bool _isUploading = false;
  final AuthService _authService = AuthService();
  bool _isStudentIdVerification = true; // [NEW] Default to Student ID

  @override
  void initState() {
    super.initState();
    analyticsService.logEvent('signup_step_2_start');
    _loadImageDraft();
    // _clearExistingSession(); // Removed to prevent triggering logout navigation
  }


  // Future<void> _clearExistingSession() async { ... } removed

  void _showImageSourceDialog(int imageType) {
    showDialog(
      context: context,
      builder: (ctx) => ImageSourcePopup(
        onCameraTap: () async {
          Navigator.pop(ctx);
          _pickImage(ImageSource.camera, imageType);
        },
        onGalleryTap: () async {
          Navigator.pop(ctx);
          _pickImage(ImageSource.gallery, imageType);
        },
      ),
    );
  }

  /// Cache paths from [ImagePicker] can be deleted by Android before upload.
  /// Copy into app documents so [MultipartFile.fromPath] still sees the file.
  Future<File> _persistPickedImage(XFile image, int imageType) async {
    final docsDir = await getApplicationDocumentsDirectory();
    final safeName =
        'signup_kyc_${imageType}_${DateTime.now().millisecondsSinceEpoch}.jpg';
    final dest = File('${docsDir.path}/$safeName');
    await File(image.path).copy(dest.path);
    return dest;
  }

  Future<void> _pickImage(ImageSource source, int imageType) async {
    try {
      final XFile? image =
          await _imagePicker.pickImage(source: source, imageQuality: 85);
      if (image != null) {
        final File persisted = await _persistPickedImage(image, imageType);
        setState(() {
          if (imageType == 0) {
            _studentIdImage = persisted;
          } else if (imageType == 1) {
            _studentIdBackImage = persisted;
          } else if (imageType == 2) {
            _cnicFrontImage = persisted;
          } else if (imageType == 3) {
            _cnicBackImage = persisted;
          } else {
            _selfieImage = persisted;
          }
        });
        _saveImageDraft();
      }
    } catch (e) {
      if (mounted) ToastUtils.handleApiError(context, e);
    }
  }

  // -------------------------------------------------------------------------
  // Draft save / restore (step 2)
  // -------------------------------------------------------------------------

  Future<void> _loadImageDraft() async {
    final draft = await signupDraftService.loadDraft();
    if (!draft.hasStep2Data) return;

    File? front, back, cnicFront, cnicBack, selfie;

    Future<File?> tryLoad(String? path) async {
      if (path == null) return null;
      final f = File(path);
      return (await f.exists()) ? f : null;
    }

    front = await tryLoad(draft.studentIdFrontPath);
    back = await tryLoad(draft.studentIdBackPath);
    cnicFront = await tryLoad(draft.cnicFrontPath);
    cnicBack = await tryLoad(draft.cnicBackPath);
    selfie = await tryLoad(draft.selfiePath);

    final hasAny =
        front != null || cnicFront != null || selfie != null;
    if (!hasAny || !mounted) return;

    setState(() {
      if (front != null) _studentIdImage = front;
      if (back != null) _studentIdBackImage = back;
      if (cnicFront != null) _cnicFrontImage = cnicFront;
      if (cnicBack != null) _cnicBackImage = cnicBack;
      if (selfie != null) _selfieImage = selfie;
      if (draft.isStudentIdVerification != null) {
        _isStudentIdVerification = draft.isStudentIdVerification!;
      }
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Row(
            children: [
              Icon(Icons.restore_rounded, color: Colors.white, size: 18),
              SizedBox(width: 8),
              Text('Previous document uploads restored.'),
            ],
          ),
          backgroundColor: AppColors.primary,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 3),
        ),
      );
    });
  }

  /// Fire-and-forget: saves current image paths to local storage.
  void _saveImageDraft() {
    signupDraftService.saveStep2(
      studentIdFrontPath: _studentIdImage?.path,
      studentIdBackPath: _studentIdBackImage?.path,
      cnicFrontPath: _cnicFrontImage?.path,
      cnicBackPath: _cnicBackImage?.path,
      selfiePath: _selfieImage?.path,
      isStudentIdVerification: _isStudentIdVerification,
    );
  }

  bool _validateForm() {
    if (_studentIdImage == null) {
      ToastUtils.showErrorToast(context,
          label: "Validation Error",
          message: _isStudentIdVerification
              ? "Upload Student ID Front"
              : "Upload Paid Fee Challan");
      return false;
    }
    // Only check back image if using Student ID verification
    if (_isStudentIdVerification && _studentIdBackImage == null) {
      ToastUtils.showErrorToast(context,
          label: "Validation Error", message: "Upload Student ID Back");
      return false;
    }
    if (_cnicFrontImage == null) {
      ToastUtils.showErrorToast(context,
          label: "Validation Error", message: "Upload CNIC Front");
      return false;
    }
    if (_cnicBackImage == null) {
      ToastUtils.showErrorToast(context,
          label: "Validation Error", message: "Upload CNIC Back");
      return false;
    }
    if (_selfieImage == null) {
      ToastUtils.showErrorToast(context,
          label: "Validation Error", message: "Upload Selfie");
      return false;
    }
    return true;
  }

  Future<void> _handleSubmit() async {
    if (!_validateForm()) return;
    setState(() => _isUploading = true);

    try {
      // If doing Challan verification, use the same image logic for 'back' to satisfy backend requirement
      // effectively uploading the challan twice or mocking the back image slot
      final File backImageToUpload = _isStudentIdVerification 
          ? _studentIdBackImage! 
          : _studentIdImage!; // Reuse challan for back slot

      final ok = await _authService.registerStudentWithDocuments(
        firstName: widget.firstName,
        lastName: widget.lastName,
        email: widget.email,
        password: widget.password,
        phone: widget.phone,
        university: widget.university,
        educationalGrade: widget.educationalGrade,
        dateOfBirth: widget.dateOfBirth,
        studentIdCardFront: _studentIdImage!,
        studentIdCardBack: backImageToUpload,
        cnicFrontImage: _cnicFrontImage!,
        cnicBackImage: _cnicBackImage!,
        selfieImage: _selfieImage!,
      );



      analyticsService.logEvent('signup_step_2_complete');
      analyticsService.logEvent('kyc_submitted');

      // Clear the local draft now that registration succeeded
      await signupDraftService.clearDraft();

      if (mounted)
        Navigator.pushReplacement(
            context,
            MaterialPageRoute(
                builder: (_) => SignupVerificationScreen(
                    parchiId: ok.parchiId,
                    email: ok.email)));

    } catch (e) {
      if (e is ConflictException || 
          e.toString().contains("Conflict") || 
          e.toString().contains("Email already registered")) {
        // [NEW] Handle Pending/Registered User Logic
        await _checkAccountStatus();
      } else {
        ToastUtils.handleApiError(context, e);
      }
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  Future<void> _checkAccountStatus() async {
     try {
       // Attempt to login to check status
       await _authService.login(
         email: widget.email,
         password: widget.password,
       );
       
       // Force fetch latest profile to get status
       await _authService.getProfile();
       final user = await _authService.getUser(); // Reload from storage
       
       if (user != null) {
          if (user.verificationStatus == 'pending') {
             // User is pending approval -> Show Success/Pending Screen
             if (mounted) {
               Navigator.pushAndRemoveUntil(
                  context,
                  MaterialPageRoute(builder: (context) => const VerificationSuccessScreen()),
                  (route) => false,
               );
             }
             return;
          } else if (user.verificationStatus == 'approved') {
             ToastUtils.showErrorToast(context, label: "Error", message: "Account already approved. Please login.");
             Future.delayed(const Duration(seconds: 2), () {
                if(mounted) {
                  Navigator.of(context).popUntil((route) => route.isFirst);
                }
             });
             return;
          }
       }
       
       // Default fallback
       ToastUtils.showErrorToast(context, label: "Error", message: "Email already registered. Please login.");
     } catch (e) {
       final errorText = e.toString().toLowerCase();
       // If signup email already exists but password doesn't match, avoid
       // showing a misleading auth error on the signup screen.
       if (errorText.contains('invalid email or password')) {
        ToastUtils.showErrorToast(
          context,
          label: "Account Exists",
          message: "This email is already registered. Please login or reset your password.",
        );
        return;
       }
       ToastUtils.handleApiError(context, e);
     }
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    // Account for Android bottom insets (gesture nav bar) so the container
    // doesn't clip the submit button on devices with tall navigation bars.
    final bottomInset = MediaQuery.of(context).padding.bottom;
    final containerHeight = (screenHeight * 0.75).clamp(0.0, screenHeight - bottomInset - 80);

    return TapToDismissKeyboard(
      child: Scaffold(
        resizeToAvoidBottomInset: true,
        body: Stack(
        children: [
          // 1. BACKGROUND (Solid color like LoginScreen)
          Container(
            color: AppColors.primary,
          ),

          // 2. LOGO & TEXT (Positioned like LoginScreen signup state)
          AnimatedPositioned(
            duration: const Duration(milliseconds: 600),
            curve: Curves.easeInOutQuart,
            top: -screenHeight * 0.10, // Moves up same as LoginScreen
            left: 0, right: 0,
            height: screenHeight * 0.45,
            child: SafeArea(
              child: Center(
                child: SizedBox(
                  width: MediaQuery.of(context).size.width * 0.5, // 0.5 width
                  child: SvgPicture.asset(
                    'assets/ParchiFullTextYellow.svg',
                    colorFilter: const ColorFilter.mode(
                        Color(0xFFE3E935), BlendMode.srcIn),
                  ),
                ),
              ),
            ),
          ),

          // 3. THE WHITE CONTAINER (Floating Bubble Style)
          AnimatedPositioned(
            duration: const Duration(milliseconds: 600),
            curve: Curves.easeInOutQuart,
            bottom: 0, left: 0, right: 0,
            height: containerHeight,
            child: Container(
              margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
              decoration: BoxDecoration(
                color: AppColors.backgroundLight,
                borderRadius: BorderRadius.circular(40),
                boxShadow: [
                  BoxShadow(
                      color: Colors.black.withOpacity(0.2),
                      blurRadius: 20,
                      offset: const Offset(0, -5))
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(40),
                child: Column(
                  children: [
                    // --- HEADER ---
                    Padding(
                      padding: const EdgeInsets.fromLTRB(24, 24, 24, 10),
                      child: Row(
                        children: [
                          GestureDetector(
                            onTap: () => Navigator.pop(context),
                            child: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                  color: AppColors.textSecondary.withOpacity(0.1),
                                  shape: BoxShape.circle),
                              child: const Icon(Icons.arrow_back,
                                  size: 20, color: AppColors.textPrimary),
                            ),
                          ),
                          const SizedBox(width: 16),
                          const Text("Verify Student",
                              style: TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold, // Bold to match "Create Account"
                                  color: AppColors.textPrimary)),
                        ],
                      ),
                    ),

                    // --- CONTENT SCROLLABLE AREA ---
                    Expanded(
                      child: SingleChildScrollView(
                        padding: EdgeInsets.fromLTRB(
                          24,
                          0,
                          24,
                          24 + MediaQuery.of(context).padding.bottom,
                        ),
                        physics: const ClampingScrollPhysics(),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(height: 10),
                            const Text(
                                "Upload your verification documents. These details are solely for verifying your student status. Provide either your Student ID OR a Secondary Document (Challan, Result Sheet, etc.)",
                                style: TextStyle(
                                    fontSize: 14,
                                    height: 1.4,
                                    color: AppColors.textSecondary)),

                            
                            const SizedBox(height: 16),

                            // [NEW] Toggle Switch
                            Container(
                              height: 40,
                              decoration: BoxDecoration(
                                color: AppColors.textSecondary.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: GestureDetector(
                                      onTap: () {
                                          setState(() => _isStudentIdVerification = true);
                                          _saveImageDraft();
                                        },
                                      child: Container(
                                        decoration: BoxDecoration(
                                          color: _isStudentIdVerification 
                                              ? AppColors.primary 
                                              : Colors.transparent,
                                          borderRadius: BorderRadius.circular(20),
                                        ),
                                        child: Center(
                                          child: Text(
                                            "Student ID",
                                            style: TextStyle(
                                              fontSize: 14,
                                              fontWeight: FontWeight.bold, // [MODIFIED] Slightly bolder
                                              color: _isStudentIdVerification 
                                                  ? AppColors.textOnPrimary 
                                                  : AppColors.textSecondary,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                  Expanded(
                                    child: GestureDetector(
                                      onTap: () {
                                          setState(() => _isStudentIdVerification = false);
                                          _saveImageDraft();
                                        },
                                      child: Container(
                                        decoration: BoxDecoration(
                                          color: !_isStudentIdVerification 
                                              ? AppColors.primary 
                                              : Colors.transparent,
                                          borderRadius: BorderRadius.circular(20),
                                        ),
                                        child: Center(
                                          child: Text(
                                            "Secondary Document",

                                            style: TextStyle(
                                              fontSize: 14,
                                              fontWeight: FontWeight.bold,
                                              color: !_isStudentIdVerification 
                                                  ? AppColors.textOnPrimary 
                                                  : AppColors.textSecondary,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            const SizedBox(height: 24),

                            _buildInputLabel(_isStudentIdVerification ? "Student ID Front *" : "Secondary Document *"),
                            _buildUploadBox(
                                _isStudentIdVerification ? "Upload ID Front" : "Upload Document",
                                _studentIdImage != null,
                                () => _showImageSourceDialog(0),
                                image: _studentIdImage),
                            
                            // Only show ID Back if Student ID is selected
                            if (_isStudentIdVerification) ...[
                              const SizedBox(height: 24),
                              _buildInputLabel("Student ID Back *"),
                              _buildUploadBox(
                                  "Upload ID Back",
                                  _studentIdBackImage != null,
                                  () => _showImageSourceDialog(1),
                                  image: _studentIdBackImage),
                            ],

                            const SizedBox(height: 24),
                            _buildInputLabel("CNIC Front *"),
                            _buildUploadBox(
                                "Upload CNIC Front",
                                _cnicFrontImage != null,
                                () => _showImageSourceDialog(2),
                                image: _cnicFrontImage),
                            const SizedBox(height: 24),
                            _buildInputLabel("CNIC Back *"),
                            _buildUploadBox(
                                "Upload CNIC Back",
                                _cnicBackImage != null,
                                () => _showImageSourceDialog(3),
                                image: _cnicBackImage),
                            const SizedBox(height: 24),
                            _buildInputLabel("Selfie Image *"),
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(16),
                              margin: const EdgeInsets.only(bottom: 16),
                              decoration: BoxDecoration(
                                color: AppColors.primary.withOpacity(0.05),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: AppColors.primary.withOpacity(0.2)),
                              ),
                              child: const Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text("Selfie Guidelines:", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.textPrimary)),
                                  SizedBox(height: 10),
                                  Text("• Headshot: Face and shoulders only", style: TextStyle(fontSize: 13, color: AppColors.textSecondary)),
                                  SizedBox(height: 6),
                                  Text("• Visibility: No glasses, masks, or hands on face", style: TextStyle(fontSize: 13, color: AppColors.textSecondary)),
                                  SizedBox(height: 6),
                                  Text("• Lighting: Good lighting (avoid heavy shadows)", style: TextStyle(fontSize: 13, color: AppColors.textSecondary)),
                                  SizedBox(height: 6),
                                  Text("• Background: Use a plain or simple background", style: TextStyle(fontSize: 13, color: AppColors.textSecondary)),
                                  SizedBox(height: 6),
                                  Text("• Recency: Photo must be recent and look like you", style: TextStyle(fontSize: 13, color: AppColors.textSecondary)),
                                  SizedBox(height: 12),
                                  Text("Tip: Hold phone at eye level in natural light.", style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: AppColors.primary)),
                                ],
                              ),
                            ),
                            _buildUploadBox(
                                "Upload Selfie",
                                _selfieImage != null,
                                () => _showImageSourceDialog(4),
                                image: _selfieImage),

                            const SizedBox(height: 30),
                            SizedBox(
                              width: double.infinity,
                              height: 56,
                              child: ElevatedButton(
                                onPressed: _isUploading ? null : _handleSubmit,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.primary,
                                  disabledBackgroundColor: AppColors.primary, // Keep it blue when disabled/loading
                                  shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(30)),
                                ),
                                child: _isUploading
                                    ? const SpinningLoader(size: 30, color: AppColors.secondary) // Use SpinningLoader
                                    : const Text("Submit Verification",
                                        style: TextStyle(
                                            color: AppColors.textOnPrimary,
                                            fontSize: 18,
                                            fontWeight: FontWeight.bold)),
                              ),
                            ),
                            // Bottom Padding
                            const SizedBox(height: 24),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    ),
    );
  }

  Widget _buildInputLabel(String text) {
    return Padding(
        padding: const EdgeInsets.only(bottom: 8.0, left: 4.0),
        child: Text(text,
            style: const TextStyle(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w600,
                fontSize: 14)));
  }

  Widget _buildUploadBox(String text, bool isUploaded, VoidCallback onTap,
      {File? image}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 200,
        width: double.infinity,
        decoration: BoxDecoration(
          color: isUploaded
              ? AppColors.textSecondary.withOpacity(0.1)
              : AppColors.textSecondary.withOpacity(0.05), // Lighter bg for empty
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
              color: isUploaded
                  ? AppColors.primary
                  : AppColors.textSecondary.withOpacity(0.3),
              width: 1.5),
        ),
        child: isUploaded && image != null
            ? ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Image.file(image,
                    fit: BoxFit.cover, width: double.infinity))
            : Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.cloud_upload_outlined,
                      size: 48,
                      color: AppColors.textSecondary.withOpacity(0.4)),
                  const SizedBox(height: 12),
                  Text(text,
                      style: const TextStyle(fontWeight: FontWeight.bold)),
                ],
              ),
      ),
    );
  }
}