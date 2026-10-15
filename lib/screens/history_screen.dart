import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../app_colors.dart';
import '../services/firestore_service.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
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

                    List<QueryDocumentSnapshot> registrations =
                        snapshot.data!.docs;

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

                    // group the events by month (example: OCTOBER 2026)
                    List<Widget> items = [];
                    String currentMonth = '';

                    for (var doc in registrations) {
                      Map data = doc.data() as Map;
                      String month = monthName('${data['dateLabel'] ?? ''}');

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

  // convert "OCT 28" to "OCTOBER 2026"
  String monthName(String dateLabel) {
    List<String> months = [
      'JANUARY', 'FEBRUARY', 'MARCH', 'APRIL', 'MAY', 'JUNE',
      'JULY', 'AUGUST', 'SEPTEMBER', 'OCTOBER', 'NOVEMBER', 'DECEMBER'
    ];
    String first = dateLabel.isEmpty ? '' : dateLabel.split(' ')[0].toUpperCase();
    int index = months.indexOf(first);
    if (index < 0) {
      // dateLabel format not recognized, just use the current month
      index = DateTime.now().month - 1;
    }
    return '${months[index]} ${DateTime.now().year}';
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

                  // completed chip
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
