import 'package:flutter/material.dart';
import '../app_colors.dart';
import '../form_feedback.dart';
import '../helpers.dart';
import '../services/firestore_service.dart';
import '../services/notification_store.dart';
import 'event_details_screen.dart';

// ------------------------------------------------------------
// NOTIFICATIONS (kept on the device — no Firestore storage)
// ------------------------------------------------------------
// The list is rendered from NotificationStore, which is a local,
// per-student list. Events it links to still load from Firestore.

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  @override
  void initState() {
    super.initState();
    // make sure this student's local list is loaded
    NotificationStore.instance.ensureLoaded();
  }

  // open a notification: read it, then open its event (if it has one)
  void openNotification(AppNotification notification) async {
    if (!notification.read) {
      await NotificationStore.instance.markRead(notification.id);
    }

    String eventId = notification.eventId;
    if (eventId.isEmpty || !mounted) return;

    var event = await FirestoreService().getEvent(eventId);
    if (!event.exists || !mounted) return;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => EventDetailsScreen(
          eventId: eventId,
          data: event.data() as Map,
        ),
      ),
    );
  }

  // the small icon on the left, based on the notification type
  Widget typeIcon(String type, bool read) {
    IconData icon = Icons.notifications_none;

    switch (type) {
      case 'registration':
        icon = Icons.check_circle_outline;
        break;
      case 'cancellation':
        icon = Icons.event_busy;
        break;
      case 'reminder':
        icon = Icons.alarm;
        break;
      case 'event':
        icon = Icons.campaign_outlined;
        break;
      case 'info':
        icon = Icons.info_outline;
        break;
    }

    return Container(
      width: 42,
      height: 42,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: read ? const Color(0xFFEDEDED) : AppColors.primary,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Icon(
        icon,
        color: read ? AppColors.greyText : Colors.white,
        size: 20,
      ),
    );
  }

  // one notification in the list
  Widget notificationCard(AppNotification notification) {
    bool read = notification.read;
    bool hasEvent = notification.eventId.isNotEmpty;
    String when = timeAgo(notification.createdAt);

    return GestureDetector(
      onTap: () => openNotification(notification),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: read ? Colors.white : const Color(0xFFF3E3E7),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFEDEDED)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            typeIcon(notification.type, read),
            const SizedBox(width: 12),

            // title, time and message
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          notification.title,
                          style: const TextStyle(
                              fontSize: 14, fontWeight: FontWeight.bold),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        when,
                        style: const TextStyle(
                            color: AppColors.greyText, fontSize: 11),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    notification.body,
                    style: const TextStyle(
                        color: AppColors.greyText, fontSize: 12),
                  ),
                ],
              ),
            ),

            const SizedBox(width: 8),

            // unread dot, or arrow when it opens an event
            read
                ? (hasEvent
                    ? const Icon(Icons.chevron_right,
                        color: AppColors.greyText)
                    : const SizedBox.shrink())
                : Container(
                    width: 9,
                    height: 9,
                    margin: const EdgeInsets.only(top: 4),
                    decoration: const BoxDecoration(
                      color: AppColors.primary,
                      shape: BoxShape.circle,
                    ),
                  ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // back button
              IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.arrow_back, color: AppColors.dark),
                padding: EdgeInsets.zero,
                alignment: Alignment.centerLeft,
              ),

              const SizedBox(height: 4),

              const Text(
                'Notifications',
                style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold),
              ),

              const SizedBox(height: 4),

              const Text(
                "Updates about your events and registrations.",
                style: TextStyle(color: AppColors.greyText, fontSize: 14),
              ),

              const SizedBox(height: 20),

              // the notification list (local, newest first)
              Expanded(
                child: ListenableBuilder(
                  listenable: NotificationStore.instance,
                  builder: (context, _) {
                    List<AppNotification> notifications =
                        NotificationStore.instance.items;

                    if (notifications.isEmpty) {
                      return const Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.notifications_none,
                              size: 60,
                              color: AppColors.greyText,
                            ),
                            SizedBox(height: 12),
                            Text(
                              'No new notifications right now.',
                              textAlign: TextAlign.center,
                              style:
                                  TextStyle(color: AppColors.greyText),
                            ),
                          ],
                        ),
                      );
                    }

                    int unread = NotificationStore.instance.unreadCount;

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // unread count + mark all read button
                        if (unread > 0)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: Row(
                              mainAxisAlignment:
                                  MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  '$unread new',
                                  style: const TextStyle(
                                      color: AppColors.primary,
                                      fontSize: 13,
                                      fontWeight: FontWeight.w500),
                                ),
                                GestureDetector(
                                  onTap: () async {
                                    await NotificationStore.instance
                                        .markAllRead();
                                    if (!context.mounted) return;
                                    showSuccessSnack(context,
                                        'All notifications marked as read.');
                                  },
                                  child: const Text(
                                    'Mark all read',
                                    style: TextStyle(
                                        color: AppColors.primary,
                                        fontSize: 13,
                                        fontWeight: FontWeight.w500),
                                  ),
                                ),
                              ],
                            ),
                          ),

                        Expanded(
                          child: ListView(
                            children: [
                              for (var notification in notifications)
                                notificationCard(notification),
                            ],
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
