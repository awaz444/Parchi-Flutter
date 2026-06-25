import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../utils/colours.dart';
import '../../../services/student_notifications_service.dart';
import '../../../models/notification_model.dart';

import 'package:custom_refresh_indicator/custom_refresh_indicator.dart';
import '../../../widgets/common/parchi_loader.dart';
import '../../../widgets/common/blinking_skeleton.dart';
import '../../../widgets/common/hagrid_text.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../providers/user_provider.dart';
import '../../../widgets/common/guest_login_prompt.dart';

class NotificationScreen extends ConsumerStatefulWidget {
  const NotificationScreen({super.key});

  @override
  ConsumerState<NotificationScreen> createState() => _NotificationScreenState();
}

class _NotificationScreenState extends ConsumerState<NotificationScreen> {
  final StudentNotificationsService _api = StudentNotificationsService();
  List<NotificationItem> _notifications = [];
  bool _isLoading = true;
  String? _errorMessage;
  bool _isRefreshing = false; // [NEW] State for custom refresh UX
  final Set<String> _expandedIds = {};

  @override
  void initState() {
    super.initState();
    // Load only when authenticated; otherwise show the guest prompt.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final user = ref.read(userProfileProvider).value;
      if (user != null) _fetchNotifications();
    });
  }

  Future<void> _fetchNotifications() async {
    final user = ref.read(userProfileProvider).value;
    if (user == null) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = null;
      });
      return;
    }

    // Only show full loading skeleton on initial load or if empty
    if (_notifications.isEmpty) {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });
    }

    try {
      final response = await _api.getNotifications();
      if (mounted) {
        setState(() {
          _notifications = response.data;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = "Failed to load notifications";
          _isLoading = false;
          // Optionally print error to console for debugging
          print(e); 
        });
      }
    }
  }

  // [NEW] Wrapper for CustomRefreshIndicator
  Future<void> _handleRefresh() async {
    // Start sequence immediately — no artificial delay.
    await _startRefreshSequence();
  }

  Future<void> _startRefreshSequence() async {
     if (!mounted) return;
     setState(() => _isRefreshing = true);
     await _fetchNotifications();
     if (mounted) setState(() => _isRefreshing = false);
  }

  Future<void> _onNotificationTap(NotificationItem notif) async {
    final isExpanded = _expandedIds.contains(notif.id);

    setState(() {
      if (isExpanded) {
        _expandedIds.remove(notif.id);
      } else {
        _expandedIds.add(notif.id);
      }
    });

    // Mark as read when first expanded
    if (!notif.isRead && !isExpanded) {
      setState(() {
        _notifications = _notifications.map((item) {
          if (item.id == notif.id) {
            return NotificationItem(
              id: item.id,
              title: item.title,
              content: item.content,
              imageUrl: item.imageUrl,
              linkUrl: item.linkUrl,
              type: item.type,
              createdAt: item.createdAt,
              isRead: true,
            );
          }
          return item;
        }).toList();
      });
      await _api.markAsRead(notif.id);
    }
  }

  Future<void> _openNotificationLink(String linkUrl) async {
    final uri = Uri.tryParse(linkUrl);
    if (uri != null) {
      try {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } catch (_) {
        // silently ignore if the URL can't be opened
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final userAsync = ref.watch(userProfileProvider);
    final bool isGuest = userAsync.maybeWhen(
      data: (user) => user == null,
      orElse: () => false,
    );

    return Scaffold(
      backgroundColor: AppColors.lightCanvas,
      appBar: AppBar(
        backgroundColor: AppColors.lightCanvas,
        scrolledUnderElevation: 0,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Icons.arrow_back, color: AppColors.primary),
        ),
        title: const HagridText(
          "Notifications",
          style: TextStyle(
            color: AppColors.textPrimary,
            fontSize: 16,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
      body: isGuest
          ? const GuestLoginPrompt(
              title: 'Sign in to view notifications',
              subtitle:
                  'Your notifications are only available when you are signed in.',
              icon: Icons.notifications_rounded,
            )
          : _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isRefreshing || (_isLoading && _notifications.isEmpty)) {
      return _buildSkeletonList();
    }

    if (_errorMessage != null && _notifications.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 48, color: AppColors.error),
            const SizedBox(height: 16),
            Text(_errorMessage!, style: const TextStyle(color: AppColors.textSecondary)),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _fetchNotifications,
               style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: AppColors.textOnPrimary,
               ),
              child: const Text("Retry"),
            ),
          ],
        ),
      );
    }

    if (_notifications.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: const [
            Icon(Icons.notifications_off_outlined, size: 64, color: AppColors.textSecondary),
            SizedBox(height: 16),
            Text(
              "No notifications yet",
              style: TextStyle(color: AppColors.textSecondary, fontSize: 16),
            ),
          ],
        ),
      );
    }

    return CustomRefreshIndicator(
      onRefresh: _handleRefresh,
      offsetToArmed: 100.0,
      builder: (BuildContext context, Widget child, IndicatorController controller) {
        return Stack(
          children: <Widget>[
            AnimatedBuilder(
              animation: controller,
              builder: (context, _) {
                return SizedBox(
                  height: controller.value * 100.0,
                  width: double.infinity,
                  child: Center(
                    child: ParchiLoader(
                      isLoading: controller.isLoading,
                      progress: controller.value,
                      color: AppColors.secondary,
                    ),
                  ),
                );
              },
            ),
            Transform.translate(
              offset: Offset(0.0, controller.value * 100.0),
              child: child,
            ),
          ],
        );
      },
      child: ListView.separated(
        padding: EdgeInsets.zero,
        itemCount: _notifications.length,
        separatorBuilder: (context, index) => const Divider(
          height: 1,
          thickness: 1.0,
          color: AppColors.surfaceVariant,
        ),
        itemBuilder: (context, index) {
          final item = _notifications[index];
          return _buildNotificationItem(item);
        },
      ),
    );
  }

  Widget _buildSkeletonList() {
    return ListView.separated(
      padding: EdgeInsets.zero,
      itemCount: 10,
      physics: const NeverScrollableScrollPhysics(),
      separatorBuilder: (context, index) => const Divider(
        height: 1,
        thickness: 1.0,
        color: AppColors.surfaceVariant,
      ),
      itemBuilder: (context, index) => _buildSkeletonItem(),
    );
  }

  Widget _buildSkeletonItem() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          BlinkingSkeleton(
            width: 50,
            height: 50,
            borderRadius: 25,
            baseColor: AppColors.textSecondary.withOpacity(0.1),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                 BlinkingSkeleton(
                    width: 150,
                    height: 16,
                    baseColor: AppColors.textPrimary.withOpacity(0.1)),
                 const SizedBox(height: 6),
                 BlinkingSkeleton(
                    width: double.infinity,
                    height: 14,
                    baseColor: AppColors.textSecondary.withOpacity(0.1)),
                 const SizedBox(height: 4),
                 BlinkingSkeleton(
                    width: 200,
                    height: 14,
                    baseColor: AppColors.textSecondary.withOpacity(0.1)),
                  const SizedBox(height: 6),
                  BlinkingSkeleton(
                    width: 60,
                    height: 12,
                    baseColor: AppColors.textSecondary.withOpacity(0.1)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNotificationItem(NotificationItem item) {
    // Highlight unread items with a background or style
    final backgroundColor = item.isRead ? Colors.transparent : AppColors.primary.withOpacity(0.05);
    final titleWeight = item.isRead ? FontWeight.w600 : FontWeight.bold;
    final textColor = item.isRead ? AppColors.textPrimary : AppColors.textPrimary;
    final isExpanded = _expandedIds.contains(item.id);

    return InkWell(
      onTap: () => _onNotificationTap(item),
      child: Container(
        color: backgroundColor,
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Circle Image
            Container(
              height: 50,
              width: 50,
              decoration: BoxDecoration(
                color: AppColors.textSecondary.withOpacity(0.1),
                shape: BoxShape.circle,
                image: item.imageUrl != null 
                    ? DecorationImage(
                        image: NetworkImage(item.imageUrl!),
                        fit: BoxFit.cover,
                      )
                    : null,
              ),
              child: item.imageUrl == null 
                  ? const Icon(Icons.notifications, color: AppColors.textSecondary) 
                  : null,
            ),
             const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                   Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          item.title,
                          style: TextStyle(
                            color: textColor,
                            fontSize: 16,
                            fontWeight: titleWeight,
                          ),
                        ),
                      ),
                      if (!item.isRead) 
                         Container(
                           width: 8, 
                           height: 8, 
                           decoration: const BoxDecoration(
                             color: AppColors.primary, 
                             shape: BoxShape.circle
                           ),
                         ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    item.content,
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 14,
                    ),
                    maxLines: isExpanded ? null : 2,
                    overflow: isExpanded ? TextOverflow.visible : TextOverflow.ellipsis,
                  ),
                  if (isExpanded &&
                      item.linkUrl != null &&
                      item.linkUrl!.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: TextButton.icon(
                        onPressed: () => _openNotificationLink(item.linkUrl!),
                        icon: const Icon(Icons.open_in_new, size: 16),
                        label: const Text('Open'),
                        style: TextButton.styleFrom(
                          foregroundColor: AppColors.primary,
                          padding: EdgeInsets.zero,
                          minimumSize: const Size(0, 32),
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 6),
                  Text(
                    _formatDate(item.createdAt),
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            AnimatedRotation(
              turns: isExpanded ? 0.5 : 0,
              duration: const Duration(milliseconds: 200),
              child: const Icon(
                Icons.keyboard_arrow_down,
                color: AppColors.textSecondary,
                size: 22,
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    final localDate = date.toLocal();
    final now = DateTime.now();
    final difference = now.difference(localDate);

    if (difference.inDays > 7) {
      return DateFormat('MMM d, y').format(localDate);
    } else if (difference.inDays >= 1) {
      return '${difference.inDays}d ago';
    } else if (difference.inHours >= 1) {
      return '${difference.inHours}h ago';
    } else if (difference.inMinutes >= 1) {
      return '${difference.inMinutes}m ago';
    } else {
      return 'Just now';
    }
  }
}
