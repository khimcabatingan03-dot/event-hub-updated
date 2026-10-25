import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../app_colors.dart';
import '../helpers.dart';
import '../services/firestore_service.dart';
import '../services/notification_service.dart';
import '../services/notification_store.dart';
import 'reminder_screen.dart';

class MyEventsScreen extends StatefulWidget {
  const MyEventsScreen({super.key});

  @override
  State<MyEventsScreen> createState() => _MyEventsScreenState();
}

class _MyEventsScreenState extends State<MyEventsScreen> {
  @override
  void initState() {
    super.initState();
    FirestoreService().syncRegistrationStatuses().ignore();
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
              const Text(
                'My Events',
                style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold),
              ),

              const SizedBox(height: 4),

              const Text(
                "Events you're registered for.",
                style: TextStyle(color: AppColors.greyText, fontSize: 14),
              ),

              const SizedBox(height: 20),

              // events list
              Expanded(
                child: StreamBuilder<QuerySnapshot>(
                  stream: FirestoreService().getMyRegistrations(),
                  builder: (context, snapshot) {
                    if (!snapshot.hasData) {
                      return const Center(
                        child: CircularProgressIndicator(
                            color: AppColors.primary),
                      );
                    }

                    // only upcoming events live here — anything that
                    // already finished belongs to the Event History tab
                    List<QueryDocumentSnapshot> registrations = snapshot
                        .data!.docs
                        .where((doc) =>
                            !isCompletedRegistration(doc.data() as Map))
                        .toList();

                    // soonest event first
                    registrations.sort((a, b) {
                      Map dataA = a.data() as Map;
                      Map dataB = b.data() as Map;
                      return eventEnd(textOf(dataA['dateLabel']),
                              textOf(dataA['timeLabel']))
                          .compareTo(eventEnd(textOf(dataB['dateLabel']),
                              textOf(dataB['timeLabel'])));
                    });

                    if (registrations.isEmpty) {
                      return const Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.event_busy,
                              size: 60,
                              color: AppColors.greyText,
                            ),
                            SizedBox(height: 12),
                            Text(
                              'No registered events yet.\nRegister to an event first!',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                  color: AppColors.greyText),
                            ),
                          ],
                        ),
                      );
                    }

                    return ListView(
                      children: [
                        for (var doc in registrations) eventCard(doc),
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

  // each registered event
  Widget eventCard(DocumentSnapshot doc) {
    Map data = doc.data() as Map;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFAFAFA),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFEEEEEE)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              // date box
              Container(
                width: 55,
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  children: [
                    Text(
                      dateDay(data['dateLabel']),
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold),
                    ),
                    Text(
                      dateMonth(data['dateLabel']),
                      style: const TextStyle(
                          color: Colors.white, fontSize: 11),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),

              // event info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      textOf(data['title']),
                      style: const TextStyle(
                          fontSize: 15, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      textOf(data['timeLabel']),
                      style: const TextStyle(
                          color: AppColors.primary, fontSize: 12),
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        const Icon(Icons.location_on,
                            size: 12, color: AppColors.greyText),
                        const SizedBox(width: 2),
                        Expanded(
                          child: Text(
                            textOf(data['location']),
                            style: const TextStyle(
                                color: AppColors.greyText, fontSize: 12),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          // registered, cancel, details buttons
          Row(
            children: [
              // registered label with check
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFFEDEDED),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.check, size: 12, color: Colors.black),
                    SizedBox(width: 4),
                    Text('Registered', style: TextStyle(fontSize: 11)),
                  ],
                ),
              ),

              const SizedBox(width: 12),

              // cancel button
              GestureDetector(
                onTap: () {
                  askCancel(doc.id, textOf(data['title']),
                      textOf(data['eventId']));
                },
                child: const Text(
                  'Cancel',
                  style: TextStyle(
                      color: AppColors.primary,
                      fontSize: 13,
                      fontWeight: FontWeight.w500),
                ),
              ),

              const Spacer(),

              // details button
              GestureDetector(
                onTap: () {
                  // open the reminder / details screen for this event
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => ReminderScreen(
                        registrationId: doc.id,
                        title: textOf(data['title']),
                        dateLabel: textOf(data['dateLabel']),
                        timeLabel: textOf(data['timeLabel']),
                        location: textOf(data['location']),
                        reminderOn: data['reminderOn'] == true,
                      ),
                    ),
                  );
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.black,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text('Details',
                      style:
                          TextStyle(color: Colors.white, fontSize: 11)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // the cancel confirmation dialog
  void askCancel(String registrationId, String title, String eventId) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // warning icon
              Container(
                width: 60,
                height: 60,
                alignment: Alignment.center,
                decoration: const BoxDecoration(
                  color: Color(0xFFF3DCE2),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.warning_amber,
                    color: AppColors.primary, size: 30),
              ),

              const SizedBox(height: 16),

              const Text(
                'Cancel registration?',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),

              const SizedBox(height: 10),

              Text(
                "You will lose your spot for $title. You can register again later.",
                textAlign: TextAlign.center,
                style: const TextStyle(
                    color: AppColors.greyText, fontSize: 13),
              ),

              const SizedBox(height: 20),

              // yes cancel button (black)
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: () async {
                    await FirestoreService()
                        .cancelRegistration(registrationId);
                    // remove the reminder too
                    await NotificationService().cancelReminder();
                    // leave a notification in the bell feed too (local)
                    await NotificationStore.instance.add(
                      title: 'Registration cancelled',
                      body:
                          'Your spot for $title was released. You can register again anytime.',
                      type: 'cancellation',
                      eventId: eventId,
                    );
                    if (context.mounted) {
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Registration cancelled.'),
                          backgroundColor: AppColors.primary,
                        ),
                      );
                    }
                  },
                  child: const Text(
                    'Yes, cancel registration',
                    style: TextStyle(color: Colors.white, fontSize: 14),
                  ),
                ),
              ),

              const SizedBox(height: 8),

              // keep registration button
              SizedBox(
                width: double.infinity,
                child: TextButton(
                  style: TextButton.styleFrom(
                    backgroundColor: const Color(0xFFF0F0F0),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: () => Navigator.pop(context),
                  child: const Text(
                    'Keep registration',
                    style: TextStyle(
                        color: Colors.black, fontSize: 14),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
