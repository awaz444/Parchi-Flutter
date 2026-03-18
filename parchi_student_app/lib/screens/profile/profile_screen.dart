import 'dart:io'; // [REQUIRED]
import 'dart:ui'; // [REQUIRED] for ImageFilter
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../utils/colours.dart';
import '../../services/auth_service.dart';
import '../../providers/user_provider.dart';
import 'Change_password/change_password_screen.dart';
import 'pfp_change/profile_picture_upload_screen.dart';
import '../../widgets/common/spinning_loader.dart'; // [REQUIRED]
import 'about_us_screen.dart'; // [NEW]
import 'help_center_screen.dart'; // [NEW]

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen>
    with TickerProviderStateMixin {
  // GENERIC MODAL CONTROLLER (Handles BOTH PFP and Password sheets)
  late AnimationController _modalController;

  // State to track WHICH sheet is open
  Widget? _activeSheetContent;
  // State to track if we should show the "Floating Avatar" effect
  bool _showFocusedAvatar = false;
  // [NEW] Track uploading state from child sheet
  bool _isUploadingPfp = false;
  File? _localPreviewImage; // [NEW] Preview local selection


  @override
  void initState() {
    super.initState();
    // Initialize the shared modal animation controller
    _modalController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
      reverseDuration: const Duration(milliseconds: 300),
    );
  }

  @override
  void dispose() {
    _modalController.dispose();
    super.dispose();
  }

  // ---------------------------------------------------------
  // LOGIC: OPENING SHEETS
  // ---------------------------------------------------------

  // 1. Open Profile Picture Sheet (With Focused Avatar)
  void _openPfpSheet() {
    setState(() {
      _activeSheetContent = ProfilePictureUploadSheet(
        onClose: _closeModal,
        onLoadingStateChanged: (isLoading) {
          if (mounted) setState(() => _isUploadingPfp = isLoading);
        },
        onImageSelected: (file) {
          if (mounted) setState(() => _localPreviewImage = file);
        },
      );
      _showFocusedAvatar = true; // <--- TRUE: Avatar stays bright on top
    });
    _modalController.forward(from: 0.0);
  }

  // 2. Open Password Sheet (Standard Blur)
  void _openPasswordSheet() {
    setState(() {
      _activeSheetContent = ChangePasswordSheet(onClose: _closeModal);
      _showFocusedAvatar =
          false; // <--- FALSE: Avatar gets blurred with background
    });
    _modalController.forward(from: 0.0);
  }

  // 3. Close Any Active Modal
  void _closeModal() {
    // Reverse animation, then clear content
    _modalController.reverse().whenComplete(() {
      if (mounted) {
        setState(() {
          _activeSheetContent = null;
          _localPreviewImage = null; // Clear preview on close
        });
      }
    });
  }

  // ---------------------------------------------------------
  // LOGIC: DRAGGING INTERACTION
  // ---------------------------------------------------------
  void _handleModalDragUpdate(DragUpdateDetails details) {
    // Normalize drag distance against screen height (~60% of screen)
    double delta =
        details.primaryDelta! / (MediaQuery.sizeOf(context).height * 0.6);
    _modalController.value -= delta; // Drag down reduces value
  }

  void _handleModalDragEnd(DragEndDetails details) {
    // Snap open or closed based on position or velocity
    if (_modalController.value > 0.5 || details.primaryVelocity! < -500) {
      _modalController.forward();
    } else {
      _closeModal();
    }
  }

  @override
  Widget build(BuildContext context) {
    final userAsync = ref.watch(userProfileProvider);
    final double topPadding = MediaQuery.paddingOf(context).top;

    // PopScope intercepts the Back Button
    return PopScope(
      canPop: false,
      onPopInvoked: (didPop) {
        if (didPop) return;
        // If our custom modal is open, close it first. Otherwise pop screen.
        if (_modalController.value > 0.1) {
          _closeModal();
        } else {
          Navigator.of(context).pop();
        }
      },
      child: Scaffold(
        backgroundColor: AppColors.primary,
        resizeToAvoidBottomInset:
            false, // Handle keyboard manually in the stack
        body: userAsync.when(
          data: (user) {
            final fName = user?.firstName ?? "Student";
            final lName = user?.lastName ?? "";
            final fullName = "$fName $lName".trim();
            final email = user?.email ?? "No Email";
            final parchiId = user?.parchiId ?? "PK-????";
            final university = user?.university ?? "University";
            final phone = user?.phone ?? "No Phone";

            // --- Reusable Avatar Builder ---
            Widget buildAvatar({required bool isInteractive}) {
              return Stack(
                children: [
                  Container(
                    padding: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(
                        color: AppColors.parchiGold, shape: BoxShape.circle),
                    child: CircleAvatar(
                      radius: 50, // Slightly smaller to fit screen
                      backgroundColor: AppColors.backgroundLight,
                      backgroundImage: (_localPreviewImage != null)
                          ? FileImage(_localPreviewImage!) as ImageProvider
                          : (user?.profilePicture != null)
                              ? NetworkImage(user!.profilePicture!)
                              : null,
                      child: (user?.profilePicture == null)
                          ? const Icon(Icons.person,
                              size: 50, color: AppColors.textSecondary)
                          : null,
                    ),
                  ),
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: GestureDetector(
                      onTap: isInteractive ? _openPfpSheet : null,
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                            color: AppColors.surfaceVariant,
                            shape: BoxShape.circle,
                            border:
                                Border.all(color: AppColors.surface, width: 2)),
                        child: const Icon(Icons.edit,
                            size: 14, color: AppColors.textSecondary),
                      ),
                    ),
                  ),
                ],
              );
            }

            return Stack(
              children: [
                // Header Actions (Back & Logout)
                Positioned(
                  top: topPadding,
                  left: 16,
                  right: 16,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.arrow_back, color: Colors.white),
                      ),
                      IconButton(
                        onPressed: () => _handleLogout(context, ref),
                        icon: const Icon(Icons.logout, color: Colors.white),
                      ),
                    ],
                  ),
                ),
                // MAIN CONTENT (Static Layout)
                SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24.0),
                    child: Column(
                      children: [
                        const SizedBox(height: 10),

                        // Logo
                        SvgPicture.asset(
                          'assets/ParchiFullTextYellow.svg',
                          height: 24,
                          colorFilter: const ColorFilter.mode(
                              AppColors.parchiGold, BlendMode.srcIn),
                        ),
                        const SizedBox(height: 20),

                        // Avatar
                        buildAvatar(isInteractive: true),
                        const SizedBox(height: 16),

                        // Name & ID
                        Text(fullName,
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 26,
                                fontFamily: 'Hagrid',
                                fontWeight: FontWeight.w800)),
                        const SizedBox(height: 4),
                        Text(parchiId,
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.bold)),

                        const SizedBox(height: 30),

                        // Details Card
                        Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: AppColors.backgroundLight,
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: [
                              BoxShadow(
                                  color: Colors.black.withOpacity(0.1),
                                  blurRadius: 10,
                                  offset: const Offset(0, 5))
                            ],
                          ),
                          child: Column(
                            children: [
                              _buildDetailRow("Email", email),
                              _buildDivider(),
                              _buildDetailRow("University", university),
                              _buildDivider(),
                              _buildDetailRow("Phone", phone),
                            ],
                          ),
                        ),

                        const SizedBox(height: 20),

                        // Actions Row
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(child: _buildActionTile(
                              icon: Icons.lock_outline,
                              label: "Change\nPassword",
                              onTap: _openPasswordSheet,
                            )),
                            const SizedBox(width: 8),
                            Expanded(child: _buildActionTile(
                              icon: Icons.help_outline,
                              label: "Help\nCenter",
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                      builder: (context) => const HelpCenterScreen()),
                                );
                              },
                            )),
                            const SizedBox(width: 8),
                            Expanded(child: _buildActionTile(
                              icon: Icons.info_outline,
                              label: "About\nUs",
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                      builder: (context) => const AboutUsScreen()),
                                );
                              },
                            )),
                            const SizedBox(width: 8),
                            Expanded(child: _buildActionTile(
                              icon: Icons.delete_forever_outlined,
                              label: "Delete\nAccount",
                              onTap: () => _handleDeleteAccount(context),
                              isDestructive: true,
                            )),
                          ],
                        ),
                        
                        const Spacer(flex: 2),
                      ],
                    ),
                  ),
                ),

                // -------------------------------------------
                // INTERACTIVE MODAL OVERLAY
                // -------------------------------------------
                AnimatedBuilder(
                  animation: _modalController,
                  builder: (context, child) {
                    // Performance optimization: Don't render if closed
                    if (_modalController.value == 0 ||
                        _activeSheetContent == null)
                      return const SizedBox.shrink();

                    return Stack(
                      children: [
                        // A. BLURRED BACKGROUND
                        // ClipRect is REQUIRED on Android — without it BackdropFilter
                        // bleeds outside its bounds and causes graphical glitches on
                        // Skia/Impeller. Opacity animates the fade; blur is kept at a
                        // fixed sigma to avoid per-frame re-composition jank on Android.
                        Positioned.fill(
                          child: ClipRect(
                            child: Opacity(
                              opacity: _modalController.value.clamp(0.0, 1.0),
                              child: GestureDetector(
                                onTap: _closeModal,
                                child: BackdropFilter(
                                  filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                                  child: Container(
                                    color: Colors.black.withOpacity(0.25),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),

                        // B. FOCUSED AVATAR (Conditional)
                        // Only render this if it's the PFP sheet (_showFocusedAvatar == true)
                        if (_showFocusedAvatar)
                          Positioned(
                            top: topPadding + 54, // Adjusted for layout alignment
                            left: 0,
                            right: 0,
                            child: Opacity(
                              opacity:
                                  _modalController.value, // Fade in with drag
                              child: Column(
                                children: [
                                  // The Bright, Sharp Avatar
                                  buildAvatar(isInteractive: false),
                                  // [UX IMPROVEMENT]: Loader Overlay
                                  if (_isUploadingPfp)
                                    Padding(
                                      padding: const EdgeInsets.only(top: 20.0),
                                      child: Container(
                                        padding: const EdgeInsets.all(8),
                                        decoration: BoxDecoration(
                                          color: Colors.black.withOpacity(0.5),
                                          borderRadius: BorderRadius.circular(20),
                                        ),
                                        child: const Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            SpinningLoader(size: 20, color: Colors.white),
                                            SizedBox(width: 8),
                                            Text("Uploading...",
                                                style: TextStyle(
                                                    color: Colors.white,
                                                    fontSize: 12,
                                                    fontWeight: FontWeight.bold)),
                                          ],
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ),

                        // C. THE SHEET CONTENT
                        Positioned(
                          left: 0, right: 0, bottom: 0,
                          // Slide up from bottom based on controller value
                          child: FractionalTranslation(
                            translation:
                                Offset(0, 1.0 - _modalController.value),
                            child: GestureDetector(
                              onVerticalDragUpdate: _handleModalDragUpdate,
                              onVerticalDragEnd: _handleModalDragEnd,
                              child: Padding(
                                // Push content up when keyboard opens (Critical for Password field)
                                padding: MediaQuery.viewInsetsOf(context),
                                child: _activeSheetContent,
                              ),
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ],
            );
          },
          loading: () => const Center(
              child: CircularProgressIndicator(color: AppColors.textOnPrimary)),
          error: (err, stack) => const Center(
              child: CircularProgressIndicator(
                  color: AppColors.textOnPrimary)), // Loading on error
        ),
      ),
    );
  }

  // --- Helper Widgets ---

  Widget _buildDivider() =>
      const Divider(height: 24, color: AppColors.surface, thickness: 1);

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 14,
                  fontWeight: FontWeight.w600)),
          Expanded(
            child: Text(value,
                textAlign: TextAlign.end,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                    color: AppColors.textSecondary, fontSize: 14)),
          ),
        ],
      ),
    );
  }

  Widget _buildActionTile({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    bool isDestructive = false,
  }) {
    final Color iconColor = isDestructive ? AppColors.error : AppColors.primary;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        // No fixed width — parent Expanded drives the size
        height: 90,
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: iconColor, size: 26),
            const SizedBox(height: 6),
            Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: isDestructive ? AppColors.error : AppColors.textPrimary,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _handleDeleteAccount(BuildContext context) async {
    final shouldProceed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: AppColors.error),
            SizedBox(width: 10),
            Text(
              'Delete Account',
              style: TextStyle(color: AppColors.error, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        content: const Text(
          'This will permanently delete your Parchi account and all associated data.\n\nYou will be taken to our secure account deletion page to complete the process.',
          style: TextStyle(color: AppColors.textPrimary, fontSize: 15),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            style: TextButton.styleFrom(foregroundColor: AppColors.textSecondary),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('Continue', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (shouldProceed == true && context.mounted) {
      final uri = Uri.parse('https://www.parchipakistan.com/account-deletion');
      bool launched = false;
      try {
        // externalApplication is the most reliable mode on both Android & iOS
        launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
      } catch (_) {
        launched = false;
      }
      if (!launched) {
        // Fallback: try platform default
        try {
          launched = await launchUrl(uri);
        } catch (_) {
          launched = false;
        }
      }
      if (!launched && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
                'Could not open the browser. Please visit parchipakistan.com/account-deletion'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  Future<void> _handleLogout(BuildContext context, WidgetRef ref) async {
    final shouldLogout = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.logout, color: AppColors.primary),
            SizedBox(width: 10),
            Text(
              'Logout',
              style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        content: const Text(
          'Are you sure you want to logout of your Parchi account?',
          style: TextStyle(color: AppColors.textPrimary, fontSize: 15),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            style: TextButton.styleFrom(foregroundColor: AppColors.textSecondary),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('Logout', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (shouldLogout == true && context.mounted) {
      showDialog(
          context: context,
          barrierDismissible: false,
          builder: (_) => const Center(
              child: CircularProgressIndicator())); // Default color is primary
      try {
        await authService.logout();
        ref.read(userProfileProvider.notifier).clearUser();
        if (context.mounted) {
          Navigator.of(context).pop(); // pops loading dialog
          Navigator.of(context).pop(); // pops ProfileScreen → back to HomeScreen
        }
      } catch (e) {
        if (context.mounted) {
          Navigator.of(context).pop();
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content: Text('Logout failed: $e'),
              backgroundColor: AppColors.error));
        }
      }
    }
  }
}
