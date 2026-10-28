import 'package:flutter/material.dart';
import '../app_colors.dart';
import '../helpers.dart';
import '../services/firestore_service.dart';
import '../services/notification_service.dart';
import '../services/notification_store.dart';

class ReminderScreen extends StatefulWidget {
  final String registrationId;
  final String title;
  final String dateLabel;
  final String timeLabel;
  final String location;
  final bool reminderOn;

  const ReminderScreen({
    super.key,
    required this.registrationId,
    required this.title,
    required this.dateLabel,
    required this.timeLabel,
    required this.location,
    required this.reminderOn,
  });

  @override
  State<ReminderScreen> createState() => _ReminderScreenState();
}

class _ReminderScreenState extends State<ReminderScreen> {
  late bool reminderOn;

  @override
  void initState() {
    super.initState();
    reminderOn = widget.reminderOn;
  }

  String fullDate(String dateLabel) {
    List<String> monthNames = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December'
    ];
    List<String> monthShort = [
      'JAN', 'FEB', 'MAR', 'APR', 'MAY', 'JUN',
      'JUL', 'AUG', 'SEP', 'OCT', 'NOV', 'DEC'
    ];
    List<String> days = [
      'Monday', 'Tuesday', 'Wednesday', 'Thursday',
      'Friday', 'Saturday', 'Sunday'
    ];

    // find the month number from the short name
    int month = monthShort.indexOf(dateMonth(dateLabel).toUpperCase()) + 1;
    int day = int.tryParse(dateDay(dateLabel)) ?? 0;

    // unknown or missing date — show the raw label instead of crashing
    if (month < 1 || day < 1) {
      return textOf(dateLabel).isEmpty ? 'Date not set' : dateLabel;
    }

    DateTime date = DateTime(DateTime.now().year, month, day);

    return '${days[date.weekday - 1]}, ${monthNames[month - 1]} $day';
  }

  // turn the reminder on or off
  void toggleReminder(bool value) async {
    setState(() {
      reminderOn = value;
    });

    // save in Firestore
    await FirestoreService()
        .setReminder(widget.registrationId, value);

    if (value) {
      // schedule the notification 1 hour before the event
      await NotificationService().scheduleReminder(
        widget.title,
        DateTime.now().add(const Duration(hours: 1)),
      );
      // and a notification in the bell feed (kept on the device)
      await NotificationStore.instance.add(
        title: 'Reminder set',
        body:
            'We will notify you 1 hour before ${widget.title} starts.',
        type: 'reminder',
      );
    } else {
      // remove the notification
      await NotificationService().cancelReminder();
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              value ? 'Reminder turned on.' : 'Reminder turned off.',
              style: const TextStyle(color: Colors.black87)),
          backgroundColor: AppColors.success,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.dark,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // back button
              IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.arrow_back, color: Colors.white),
                padding: EdgeInsets.zero,
                alignment: Alignment.centerLeft,
              ),

              const Spacer(),

              // date (example: Wednesday, October 28)
              Center(
                child: Text(
                  fullDate(widget.dateLabel),
                  style: const TextStyle(
                      color: AppColors.greyText, fontSize: 15),
                ),
              ),

              const SizedBox(height: 10),

              // big time
              Center(
                child: Text(
                  widget.timeLabel.split(' - ')[0],
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 64,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),

              const SizedBox(height: 30),

              // starting in card (looks like a notification)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.darkCard,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // app icon
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: AppColors.primary,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.event,
                          color: Colors.white, size: 18),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // app name and time
                          const Row(
                            mainAxisAlignment:
                                MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'EVENTHUB',
                                style: TextStyle(
                                    color: AppColors.greyText,
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold),
                              ),
                              Text(
                                'now',
                                style: TextStyle(
                                    color: AppColors.greyText,
                                    fontSize: 11),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            'Starting in 1 hour',
                            style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${widget.title} · ${widget.timeLabel.split(' - ')[0]} at ${widget.location}. Tap to view details.',
                            style: const TextStyle(
                                color: AppColors.greyText, fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 12),

              // registration confirmed card
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.darkCard,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: AppColors.primary,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.event,
                          color: Colors.white, size: 18),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Row(
                            mainAxisAlignment:
                                MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'EVENTHUB',
                                style: TextStyle(
                                    color: AppColors.greyText,
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold),
                              ),
                              Text(
                                '2h ago',
                                style: TextStyle(
                                    color: AppColors.greyText,
                                    fontSize: 11),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            'Registration confirmed',
                            style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'You are registered for ${widget.title}.',
                            style: const TextStyle(
                                color: AppColors.greyText, fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const Spacer(),

              // reminder switch
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.darkCard,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Event reminder',
                      style: TextStyle(color: Colors.white, fontSize: 15),
                    ),
                    Switch(
                      value: reminderOn,
                      activeThumbColor: AppColors.primary,
                      onChanged: toggleReminder,
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 10),

              Center(
                child: Text(
                  reminderOn
                      ? 'Your reminder is active.'
                      : 'Turn on to get notified.',
                  style: const TextStyle(
                      color: AppColors.greyText, fontSize: 13),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
