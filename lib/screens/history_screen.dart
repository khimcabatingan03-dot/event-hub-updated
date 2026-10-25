import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../app_colors.dart';
import '../helpers.dart';
import '../services/firestore_service.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  @override
  void initState() {
    super.initState();
    // persist the right status in the background: finished events get
    // "completed" here. The list below is filtered by date anyway, so
    // a failed write never breaks what's on screen.
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
                'Event History',
                style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold),
              ),

              const SizedBox(height: 4),

              const Text(
                'Events that are done.',
                style: TextStyle(color: AppColors.greyText, fontSize: 14),
              ),

              const SizedBox(height: 20),

              // completed events list
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

                    // only events that are already finished live here;
                    // upcoming ones stay in the My Events tab
                    List<QueryDocumentSnapshot> registrations = snapshot
                        .data!.docs
                        .where((doc) =>
                            isCompletedRegistration(doc.data() as Map))
                        .toList();

                    // newest first so every month groups together
                    // under a single header
                    registrations.sort((a, b) {
                      Map dataA = a.data() as Map;
                      Map dataB = b.data() as Map;
                      return finishedAt(textOf(dataB['dateLabel']),
                              textOf(dataB['timeLabel']))
                          .compareTo(finishedAt(textOf(dataA['dateLabel']),
                              textOf(dataA['timeLabel'])));
                    });

                    if (registrations.isEmpty) {
                      return const Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.history,
                                size: 60, color: AppColors.greyText),
                            SizedBox(height: 12),
                            Text(
                              'No event history yet.',
                              style:
                                  TextStyle(color: AppColors.greyText),
                            ),
                          ],
                        ),
                      );
                    }

                    // group the events by month
                    List<Widget> items = [];
                    String currentMonth = '';

                    for (var doc in registrations) {
                      Map data = doc.data() as Map;
                      DateTime when = finishedAt(
                          textOf(data['dateLabel']), textOf(data['timeLabel']));
                      String month = monthHeader(when);

                      // add the month header when it changes
                      if (month != currentMonth) {
                        currentMonth = month;
                        items.add(Padding(
                          padding: const EdgeInsets.only(
                              top: 8, bottom: 12),
                          child: Text(
                            month,
                            style: const TextStyle(
                                color: AppColors.greyText,
                                fontSize: 12,
                                fontWeight: FontWeight.bold),
                          ),
                        ));
                      }

                      items.add(historyTile(doc, data));
                    }

                    return ListView(children: items);
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String monthHeader(DateTime when) {
    List<String> months = [
      'JANUARY', 'FEBRUARY', 'MARCH', 'APRIL', 'MAY', 'JUNE',
      'JULY', 'AUGUST', 'SEPTEMBER', 'OCTOBER', 'NOVEMBER', 'DECEMBER'
    ];
    return '${months[when.month - 1]} ${when.year}';
  }

  // each history item
  Widget historyTile(DocumentSnapshot doc, Map data) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // timeline dot and line
          Column(
            children: [
              Container(
                width: 14,
                height: 14,
                decoration: const BoxDecoration(
                  color: AppColors.primary,
                  shape: BoxShape.circle,
                ),
              ),
              Container(
                width: 2,
                height: 80,
                color: AppColors.primary,
              ),
            ],
          ),

          const SizedBox(width: 12),

          // event card
          Expanded(
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFFAFAFA),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFEEEEEE)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${data['title'] ?? 'Event'}',
                    style: const TextStyle(
                        fontSize: 15, fontWeight: FontWeight.bold),
                  ),

                  const SizedBox(height: 6),

                  Row(
                    children: [
                      const Icon(Icons.calendar_today,
                          size: 12, color: AppColors.greyText),
                      const SizedBox(width: 4),
                      Text(
                        '${data['dateLabel'] ?? ''} · ${'${data['timeLabel'] ?? ''}'.split(' - ')[0]}',
                        style: const TextStyle(
                            color: AppColors.greyText, fontSize: 12),
                      ),
                    ],
                  ),

                  const SizedBox(height: 4),

                  Row(
                    children: [
                      const Icon(Icons.location_on,
                          size: 12, color: AppColors.greyText),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          '${data['location'] ?? ''}',
                          style: const TextStyle(
                              color: AppColors.greyText, fontSize: 12),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 8),

                  // completed 
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEDEDED),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.check,
                            size: 12, color: AppColors.greyText),
                        SizedBox(width: 4),
                        Text(
                          'Completed',
                          style: TextStyle(
                              color: AppColors.greyText, fontSize: 11),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
