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
  File? _selfieImage;
  bool _isUploading = false;
  bool _agreedToTerms = false;
  bool _declaresStudentStatus = false;
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

    File? front, back, selfie;

    Future<File?> tryLoad(String? path) async {
      if (path == null) return null;
      final f = File(path);
      return (await f.exists()) ? f : null;
    }

    front = await tryLoad(draft.studentIdFrontPath);
    back = await tryLoad(draft.studentIdBackPath);
    selfie = await tryLoad(draft.selfiePath);

    final hasAny =
        front != null || selfie != null;
    if (!hasAny || !mounted) return;

    setState(() {
      if (front != null) _studentIdImage = front;
      if (back != null) _studentIdBackImage = back;
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
    if (_selfieImage == null) {
      ToastUtils.showErrorToast(context,
          label: "Validation Error", message: "Upload Selfie");
      return false;
    }
    if (!_agreedToTerms) {
      ToastUtils.showErrorToast(context,
          label: "Validation Error",
          message: "Please acknowledge the Terms & Conditions");
      return false;
    }
    if (!_declaresStudentStatus) {
      ToastUtils.showErrorToast(context,
          label: "Validation Error",
          message: "Please declare your student status");
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
                                "Verify your student status to unlock exclusive deals. You can use your Student ID or any other proof of enrollment.",
                                style: TextStyle(
                                    fontSize: 14,
                                    height: 1.4,
                                    color: AppColors.textSecondary)),

                            const SizedBox(height: 24),

                            // --- VERIFICATION TYPE SELECTION ---
                            if (_isStudentIdVerification) ...[
                              _buildInputLabel("Student ID Front *"),
                              _buildUploadBox(
                                  "Upload ID Front",
                                  _studentIdImage != null,
                                  () => _showImageSourceDialog(0),
                                  image: _studentIdImage),
                              
                              const SizedBox(height: 24),
                              _buildInputLabel("Student ID Back *"),
                              _buildUploadBox(
                                  "Upload ID Back",
                                  _studentIdBackImage != null,
                                  () => _showImageSourceDialog(1),
                                  image: _studentIdBackImage),

                              const SizedBox(height: 20),
                              Center(
                                child: TextButton(
                                  onPressed: () {
                                    setState(() {
                                      _isStudentIdVerification = false;
                                      // Clear images if switching to avoid confusion, 
                                      // though keeping them might be preferred by some.
                                      // User said "if a student gives a secondary doc, they should not be allowed to give student id front and back"
                                      _studentIdImage = null;
                                      _studentIdBackImage = null;
                                    });
                                    _saveImageDraft();
                                  },
                                  child: const Text(
                                    "Don't have a student ID card?",
                                    style: TextStyle(
                                      color: AppColors.primary,
                                      fontWeight: FontWeight.bold,
                                      decoration: TextDecoration.underline,
                                    ),
                                  ),
                                ),
                              ),
                            ] else ...[
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  _buildInputLabel("Secondary Document *"),
                                  TextButton(
                                    onPressed: () {
                                      setState(() {
                                        _isStudentIdVerification = true;
                                        _studentIdImage = null;
                                      });
                                      _saveImageDraft();
                                    },
                                    child: const Text(
                                      "Use Student ID instead",
                                      style: TextStyle(
                                        color: AppColors.primary,
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              _buildUploadBox(
                                  "Upload Proof (Challan, Result, etc.)",
                                  _studentIdImage != null,
                                  () => _showImageSourceDialog(0),
                                  image: _studentIdImage),
                              const SizedBox(height: 8),
                              const Text(
                                "Upload any document that proves your current enrollment (e.g., Fee Challan, Admission Letter, or Result Sheet).",
                                style: TextStyle(
                                  fontSize: 12,
                                  color: AppColors.textSecondary,
                                  fontStyle: FontStyle.italic,
                                ),
                              ),
                            ],

                            const SizedBox(height: 32),
                            _buildInputLabel("Selfie Image *"),
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(20),
                              margin: const EdgeInsets.only(bottom: 20),
                              decoration: BoxDecoration(
                                color: AppColors.primary.withOpacity(0.08),
                                borderRadius: BorderRadius.circular(24),
                                border: Border.all(color: AppColors.primary.withOpacity(0.2), width: 1.5),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(6),
                                        decoration: BoxDecoration(
                                          color: AppColors.primary,
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        child: const Icon(Icons.face_retouching_natural_rounded, color: Colors.white, size: 20),
                                      ),
                                      const SizedBox(width: 12),
                                      const Text("Selfie Guidelines", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppColors.textPrimary)),
                                    ],
                                  ),
                                  const SizedBox(height: 16),
                                  _buildGuidelineRow(Icons.check_circle_outline_rounded, "Headshot: Face and shoulders only"),
                                  _buildGuidelineRow(Icons.check_circle_outline_rounded, "Visibility: No glasses, masks, or hats"),
                                  _buildGuidelineRow(Icons.check_circle_outline_rounded, "Lighting: Good lighting, avoid shadows"),
                                  _buildGuidelineRow(Icons.check_circle_outline_rounded, "Background: Use a plain background"),
                                  const SizedBox(height: 12),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                    decoration: BoxDecoration(
                                      color: AppColors.primary.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: const Text(
                                      "Tip: Hold phone at eye level in natural light.",
                                      style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: AppColors.primary),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            _buildUploadBox(
                                "Upload Selfie",
                                _selfieImage != null,
                                () => _showImageSourceDialog(2),
                                image: _selfieImage),

                            const SizedBox(height: 30),

                            // ── Declarations ──────────────────────────────
                            GestureDetector(
                              onTap: () => setState(() => _agreedToTerms = !_agreedToTerms),
                              child: Container(
                                padding: const EdgeInsets.symmetric(vertical: 4),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    SizedBox(
                                      height: 24,
                                      width: 24,
                                      child: Checkbox(
                                        value: _agreedToTerms,
                                        activeColor: AppColors.primary,
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                                        onChanged: (v) => setState(() => _agreedToTerms = v ?? false),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    const Expanded(
                                      child: Text(
                                        "I acknowledge and agree to the Terms & Conditions of Parchi.",
                                        style: TextStyle(fontSize: 13, color: AppColors.textSecondary, height: 1.4),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(height: 12),
                            GestureDetector(
                              onTap: () => setState(() => _declaresStudentStatus = !_declaresStudentStatus),
                              child: Container(
                                padding: const EdgeInsets.symmetric(vertical: 4),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    SizedBox(
                                      height: 24,
                                      width: 24,
                                      child: Checkbox(
                                        value: _declaresStudentStatus,
                                        activeColor: AppColors.primary,
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                                        onChanged: (v) => setState(() => _declaresStudentStatus = v ?? false),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    const Expanded(
                                      child: Text(
                                        "I declare that I am a currently enrolled student and the documents I have submitted are authentic.",
                                        style: TextStyle(fontSize: 13, color: AppColors.textSecondary, height: 1.4),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),

                            const SizedBox(height: 20),
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

  Widget _buildGuidelineRow(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Row(
        children: [
          Icon(icon, color: AppColors.primary, size: 18),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(fontSize: 13, color: AppColors.textSecondary, height: 1.4),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInputLabel(String text) {
    return Padding(
        padding: const EdgeInsets.only(bottom: 8.0, left: 4.0),
        child: Text(text,
            style: const TextStyle(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w700,
                fontSize: 15)));
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
              ? Colors.white
              : AppColors.textSecondary.withOpacity(0.03),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
              color: isUploaded
                  ? AppColors.primary
                  : AppColors.textSecondary.withOpacity(0.2),
              width: 2,
              style: isUploaded ? BorderStyle.solid : BorderStyle.solid), // Could use dashed if a package was available
          boxShadow: isUploaded ? [
            BoxShadow(
              color: AppColors.primary.withOpacity(0.1),
              blurRadius: 10,
              offset: const Offset(0, 4),
            )
          ] : null,
        ),
        child: isUploaded && image != null
            ? ClipRRect(
                borderRadius: BorderRadius.circular(22),
                child: Stack(
                  children: [
                    Image.file(image,
                        fit: BoxFit.cover, width: double.infinity),
                    Positioned(
                      top: 12,
                      right: 12,
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: const BoxDecoration(
                          color: AppColors.primary,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.check, color: Colors.white, size: 16),
                      ),
                    ),
                  ],
                ))
            : Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.add_a_photo_rounded,
                        size: 32,
                        color: AppColors.primary),
                  ),
                  const SizedBox(height: 16),
                  Text(text,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                        fontSize: 15,
                      )),
                  const SizedBox(height: 4),
                  Text("Tap to capture or upload",
                      style: TextStyle(
                        color: AppColors.textSecondary.withOpacity(0.7),
                        fontSize: 12,
                      )),
                ],
              ),
      ),
    );
  }
}