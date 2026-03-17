import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../utils/colours.dart';
import '../../../services/student_notifications_service.dart';
import '../../../models/notification_model.dart';

import 'package:custom_refresh_indicator/custom_refresh_indicator.dart';
import '../../../widgets/common/parchi_loader.dart';
import '../../../widgets/common/blinking_skeleton.dart';

class NotificationScreen extends StatefulWidget {
  const NotificationScreen({super.key});

  @override
  State<NotificationScreen> createState() => _NotificationScreenState();
}

class _NotificationScreenState extends State<NotificationScreen> {
  final StudentNotificationsService _api = StudentNotificationsService();
  List<NotificationItem> _notifications = [];
  bool _isLoading = true;
  String? _errorMessage;
  bool _isRefreshing = false; // [NEW] State for custom refresh UX

  @override
  void initState() {
    super.initState();
    _fetchNotifications();
  }

  Future<void> _fetchNotifications() async {
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
    _startRefreshSequence();
  }

  Future<void> _startRefreshSequence() async {
     setState(() => _isRefreshing = true);
     await _fetchNotifications();
     if (mounted) setState(() => _isRefreshing = false);
  }

  Future<void> _onNotificationTap(NotificationItem notif) async {
    // 1. Optimistic UI Update
    if (!notif.isRead) {
      setState(() {
        // Create a new list with modified item
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
               isRead: true, // Mark as read
             );
          }
          return item;
        }).toList();
      });
      // 2. Fire and Forget API Call
      await _api.markAsRead(notif.id);
    }

    // 3. Handle Navigation (Deep Linking placeholder)
    if (notif.linkUrl != null && notif.linkUrl!.isNotEmpty) {
       // Deep linking logic would go here
       print("Navigating to: ${notif.linkUrl}");
    }
  }

  @override
  Widget build(BuildContext context) {
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
        title: const Text(
          "Notifications",
          style: TextStyle(
            color: AppColors.textPrimary,
            fontSize: 16,
            fontWeight: FontWeight.w800,
            fontFamily: 'Hagrid',
          ),
        ),
      ),
      body: _buildBody(),
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
                  // Description
                  Text(
                    item.content,
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 14,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
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
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays > 7) {
      return DateFormat('MMM d, y').format(date);
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
