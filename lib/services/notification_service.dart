import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

class NotificationService {
  // make it a single object we can use anywhere
  static final NotificationService _instance = NotificationService._();
  factory NotificationService() => _instance;
  NotificationService._();

  final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();

  // start the notifications when the app opens
  Future<void> init() async {
    tz_data.initializeTimeZones();

    const AndroidInitializationSettings androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const InitializationSettings settings =
        InitializationSettings(android: androidSettings);

    await _notifications.initialize(settings: settings);
  }

  // ask permission (Android 13 and up)
  Future<void> askPermission() async {
    await _notifications
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();
  }

  // show a reminder 1 hour before the event
  Future<void> scheduleReminder(String title, DateTime eventTime) async {
    const AndroidNotificationDetails androidDetails =
        AndroidNotificationDetails(
      'event_reminders',
      'Event Reminders',
      channelDescription: 'Reminders for registered school events',
      importance: Importance.high,
      priority: Priority.high,
    );

    const NotificationDetails details =
        NotificationDetails(android: androidDetails);

    // 1 hour before the event
    DateTime reminderTime = eventTime.subtract(const Duration(hours: 1));

    // if the time already passed, show it after 5 seconds (for testing)
    Duration delay = reminderTime.difference(DateTime.now());
    if (delay.isNegative) {
      delay = const Duration(seconds: 5);
    }

    await _notifications.zonedSchedule(
      id: 0, // notification id
      title: 'Event Reminder',
      body: 'Starting in 1 hour: $title',
      scheduledDate: tz.TZDateTime.now(tz.local).add(delay),
      notificationDetails: details,
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
    );
  }

  // remove the reminder
  Future<void> cancelReminder() async {
    await _notifications.cancel(id: 0);
  }
}
