import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../app_colors.dart';
import '../helpers.dart';
import '../services/firestore_service.dart';
import 'event_details_screen.dart';

class CategoriesScreen extends StatefulWidget {
  const CategoriesScreen({super.key});

  @override
  State<CategoriesScreen> createState() => _CategoriesScreenState();
}

class _CategoriesScreenState extends State<CategoriesScreen> {
  // the category the student picked (null = show all)
  String? chosenCategory;

  // all the categories in the app
  final List<Map> categories = [
    {'name': 'Academic', 'icon': Icons.menu_book, 'color': AppColors.primary},
    {'name': 'Sports', 'icon': Icons.language, 'color': Colors.black},
    {'name': 'Seminar', 'icon': Icons.computer, 'color': AppColors.primary},
    {'name': 'Organization', 'icon': Icons.groups, 'color': Colors.black},
    {'name': 'Entertainment', 'icon': Icons.music_note, 'color': AppColors.primary},
  ];

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
                icon: const Icon(Icons.arrow_back),
                padding: EdgeInsets.zero,
                alignment: Alignment.centerLeft,
              ),

              const SizedBox(height: 10),

              const Text(
                'Categories',
                style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold),
              ),

              const SizedBox(height: 4),

              const Text(
                'Browse events by interest.',
                style: TextStyle(color: AppColors.greyText, fontSize: 14),
              ),

              const SizedBox(height: 20),

              // category grid
              Expanded(
                child: chosenCategory == null
                    ? Column(
                        children: [
                          Expanded(
                            child: GridView.count(
                              crossAxisCount: 2,
                              mainAxisSpacing: 12,
                              crossAxisSpacing: 12,
                              childAspectRatio: 1.3,
                              children: [
                                for (var cat in categories)
                                  GestureDetector(
                                    onTap: () {
                                      setState(() {
                                        chosenCategory = cat['name'];
                                      });
                                    },
                                    child: Container(
                                      padding: const EdgeInsets.all(14),
                                      decoration: BoxDecoration(
                                        color: cat['color'],
                                        borderRadius:
                                            BorderRadius.circular(16),
                                      ),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          // icon and arrow on top
                                          Row(
                                            mainAxisAlignment:
                                                MainAxisAlignment
                                                    .spaceBetween,
                                            children: [
                                              Icon(cat['icon'],
                                                  color: Colors.white,
                                                  size: 22),
                                              const Icon(
                                                  Icons.arrow_forward,
                                                  color: Colors.white,
                                                  size: 16),
                                            ],
                                          ),
                                          const Spacer(),
                                          Text(
                                            cat['name'],
                                            style: const TextStyle(
                                                color: Colors.white,
                                                fontSize: 15,
                                                fontWeight:
                                                    FontWeight.bold),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),

                          const SizedBox(height: 12),

                          // view all events card
                          GestureDetector(
                            onTap: () {
                              setState(() {
                                chosenCategory = 'All';
                              });
                            },
                            child: Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF3F3F3),
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  const Text(
                                    'View all events',
                                    style: TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.bold),
                                  ),
                                  Container(
                                    width: 36,
                                    height: 36,
                                    alignment: Alignment.center,
                                    decoration: const BoxDecoration(
                                      color: Colors.black,
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(
                                        Icons.arrow_forward,
                                        color: Colors.white,
                                        size: 18),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      )
                    : eventList(chosenCategory!),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // list of events for one category
  Widget eventList(String category) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              category == 'All' ? 'All events' : category,
              style:
                  const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            TextButton(
              onPressed: () {
                setState(() {
                  chosenCategory = null;
                });
              },
              child: const Text('Back to categories',
                  style: TextStyle(color: AppColors.primary)),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            // 'All' shows every event, otherwise only that category
            stream: category == 'All'
                ? FirestoreService().getEvents()
                : FirestoreService().getEventsByCategory(category),
            builder: (context, snapshot) {
              if (!snapshot.hasData) {
                return const Center(
                  child: CircularProgressIndicator(color: AppColors.primary),
                );
              }

              List<QueryDocumentSnapshot> events = snapshot.data!.docs;

              if (events.isEmpty) {
                return const Center(
                  child: Text('No events in this category yet.',
                      style: TextStyle(color: AppColors.greyText)),
                );
              }

              return ListView(
                children: [
                  for (var event in events)
                    eventTile(event, event.data() as Map),
                ],
              );
            },
          ),
        ),
      ],
    );
  }

  // each event tile
  Widget eventTile(DocumentSnapshot event, Map data) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) =>
                EventDetailsScreen(eventId: event.id, data: data),
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFFF5F5F5),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.asset(
                textOf(data['image']),
                width: 50,
                height: 50,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => Container(
                  width: 50,
                  height: 50,
                  color: AppColors.primary,
                  child: const Icon(Icons.event, color: Colors.white),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    textOf(data['title']),
                    style: const TextStyle(
                        fontSize: 14, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${textOf(data['dateLabel'])} • ${textOf(data['location'])}',
                    style: const TextStyle(
                        color: AppColors.greyText, fontSize: 12),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: AppColors.greyText),
          ],
        ),
      ),
    );
  }
}
