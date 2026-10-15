import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../app_colors.dart';
import '../helpers.dart';
import '../services/firestore_service.dart';
import 'event_details_screen.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  // open a notification: read it, then open its event (if it has one)
  void openNotification(DocumentSnapshot doc) async {
    Map data = doc.data() as Map;

    if (data['read'] != true) {
      await FirestoreService().markNotificationRead(doc.id);
    }

    String eventId = textOf(data['eventId']);
    if (eventId.isEmpty || !mounted) return;

    DocumentSnapshot event = await FirestoreService().getEvent(eventId);
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
  Widget notificationCard(DocumentSnapshot doc) {
    Map data = doc.data() as Map;
    bool read = data['read'] == true;
    bool hasEvent = textOf(data['eventId']).isNotEmpty;

    dynamic createdAt = data['createdAt'];
    String when = createdAt is Timestamp
        ? timeAgo(createdAt.toDate())
        : '';

    return GestureDetector(
      onTap: () => openNotification(doc),
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
            typeIcon(textOf(data['type']), read),
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
                          textOf(data['title']),
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
                    textOf(data['body']),
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

              // the notification list
              Expanded(
                child: StreamBuilder<QuerySnapshot>(
                  stream: FirestoreService().getMyNotifications(),
                  builder: (context, snapshot) {
                    if (!snapshot.hasData) {
                      return const Center(
                        child: CircularProgressIndicator(
                            color: AppColors.primary),
                      );
                    }

                    List<QueryDocumentSnapshot> notifications =
                        snapshot.data!.docs;

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

                    // newest first
                    notifications.sort((a, b) {
                      final dynamic ta = (a.data() as Map)['createdAt'];
                      final dynamic tb = (b.data() as Map)['createdAt'];
                      if (ta is Timestamp && tb is Timestamp) {
                        return tb.compareTo(ta);
                      }
                      return 0;
                    });

                    int unread = notifications
                        .where((doc) => (doc.data() as Map)['read'] != true)
                        .length;

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
                                    await FirestoreService()
                                        .markAllNotificationsRead();
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
                              for (var doc in notifications)
                                notificationCard(doc),
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
