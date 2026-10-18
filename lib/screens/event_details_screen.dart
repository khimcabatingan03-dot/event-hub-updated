import 'package:flutter/material.dart';
import '../app_colors.dart';
import '../helpers.dart';
import '../services/firestore_service.dart';
import '../services/notification_service.dart';
import '../services/notification_store.dart';
import 'location_screen.dart';

class EventDetailsScreen extends StatefulWidget {
  final String eventId;
  final Map data;

  const EventDetailsScreen(
      {super.key, required this.eventId, required this.data});

  @override
  State<EventDetailsScreen> createState() => _EventDetailsScreenState();
}

class _EventDetailsScreenState extends State<EventDetailsScreen> {
  bool alreadyRegistered = false;
  bool loading = true;
  bool bookmarked = false;

  @override
  void initState() {
    super.initState();
    checkRegistration();
  }

  // check if the student already registered here
  void checkRegistration() async {
    bool registered =
        await FirestoreService().isRegistered(widget.eventId);
    setState(() {
      alreadyRegistered = registered;
      loading = false;
    });
  }

  // press the register now button
  void registerNow() {
    // reminder switch value (starts off)
    bool reminderOn = false;

    showModalBottomSheet(
      context: context,
      // the sheet covers the full screen, not just the area above
      // the bottom navigation bar
      useRootNavigator: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Confirm registration',
                    style: TextStyle(
                        fontSize: 20, fontWeight: FontWeight.bold),
                  ),

                  const SizedBox(height: 20),

                  // event summary
                  Container(
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
                            textOf(widget.data['image']),
                            width: 50,
                            height: 50,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) =>
                                Container(
                              width: 50,
                              height: 50,
                              color: AppColors.primary,
                              child: const Icon(Icons.event,
                                  color: Colors.white),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                textOf(widget.data['title']),
                                style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '${textOf(widget.data['dateLabel'])} • ${timeStart(widget.data['timeLabel'])}',
                                style: const TextStyle(
                                    color: AppColors.primary, fontSize: 12),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                textOf(widget.data['location']),
                                style: const TextStyle(
                                    color: AppColors.greyText,
                                    fontSize: 12),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),

                  // reminder switch
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Remind me 1 hour before',
                          style: TextStyle(fontSize: 14)),
                      Switch(
                        value: reminderOn,
                        activeThumbColor: AppColors.primary,
                        onChanged: (value) {
                          setSheetState(() {
                            reminderOn = value;
                          });
                        },
                      ),
                    ],
                  ),

                  const SizedBox(height: 20),

                  // confirm button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(30),
                        ),
                      ),
                      onPressed: () {
                        saveRegistration(reminderOn);
                        Navigator.pop(context);
                      },
                      child: const Text(
                        'Confirm registration',
                        style: TextStyle(color: Colors.white, fontSize: 16),
                      ),
                    ),
                  ),

                  const SizedBox(height: 10),

                  // not now button
                  Center(
                    child: TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Not now',
                          style: TextStyle(color: AppColors.greyText)),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  // save the registration in Firestore
  void saveRegistration(bool reminderOn) async {
    await FirestoreService().registerToEvent(
      eventId: widget.eventId,
      title: textOf(widget.data['title']),
      category: textOf(widget.data['category']),
      dateLabel: textOf(widget.data['dateLabel']),
      timeLabel: textOf(widget.data['timeLabel']),
      location: textOf(widget.data['location']),
      image: textOf(widget.data['image']),
      reminderOn: reminderOn,
    );

    // schedule the local notification if the switch was on
    if (reminderOn) {
      DateTime eventTime =
          getEventTime(widget.data['dateLabel'], widget.data['timeLabel']);
      await NotificationService()
          .scheduleReminder(textOf(widget.data['title']), eventTime);
    }

    // leave a notification in the bell feed too (kept on the device)
    await NotificationStore.instance.add(
      title: 'Registration confirmed',
      body:
          'You are registered for ${textOf(widget.data['title'])} on ${textOf(widget.data['dateLabel'])} at ${timeStart(widget.data['timeLabel'])}.',
      type: 'registration',
      eventId: widget.eventId,
    );

    setState(() {
      alreadyRegistered = true;
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Registration saved! See it in My Events.'),
          backgroundColor: AppColors.primary,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.dark,
      body: SafeArea(
        child: Column(
          children: [
            // top image
            Stack(
              children: [
                Image.asset(
                  textOf(widget.data['image']),
                  width: double.infinity,
                  height: 220,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) => Container(
                    width: double.infinity,
                    height: 220,
                    color: AppColors.primary,
                    child: const Icon(Icons.event,
                        color: Colors.white, size: 60),
                  ),
                ),
                // dark overlay
                Container(
                  width: double.infinity,
                  height: 220,
                  color: Colors.black38,
                ),
                // back button
                Positioned(
                  top: 10,
                  left: 10,
                  child: IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.arrow_back, color: Colors.white),
                  ),
                ),
                // share button
                Positioned(
                  top: 10,
                  right: 60,
                  child: IconButton(
                    onPressed: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Share link copied.'),
                          backgroundColor: AppColors.primary,
                        ),
                      );
                    },
                    icon: const Icon(Icons.share, color: Colors.white),
                  ),
                ),
                // bookmark button
                Positioned(
                  top: 10,
                  right: 10,
                  child: IconButton(
                    onPressed: () {
                      setState(() {
                        bookmarked = !bookmarked;
                      });
                    },
                    icon: Icon(
                      bookmarked
                          ? Icons.bookmark
                          : Icons.bookmark_border,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),

            // white content
            Expanded(
              child: Container(
                width: double.infinity,
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius:
                      BorderRadius.vertical(top: Radius.circular(24)),
                ),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // category label
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: AppColors.primary,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          textOf(widget.data['category']),
                          style: const TextStyle(
                              color: Colors.white, fontSize: 12),
                        ),
                      ),

                      const SizedBox(height: 12),

                      // title
                      Text(
                        textOf(widget.data['title']),
                        style: const TextStyle(
                            fontSize: 22, fontWeight: FontWeight.bold),
                      ),

                      const SizedBox(height: 20),

                      // date and time side by side
                      Row(
                        children: [
                          Expanded(
                            child: infoCard(
                              Icons.calendar_today,
                              'Date',
                              textOf(widget.data['dateLabel']),
                              true,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: infoCard(
                              Icons.access_time,
                              'Time',
                              timeStart(widget.data['timeLabel']),
                              false,
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 12),

                      // location card (tap to open the map)
                      GestureDetector(
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => LocationScreen(
                                title: textOf(widget.data['title']),
                                location: textOf(widget.data['location']),
                                dateLabel: textOf(widget.data['dateLabel']),
                                timeLabel: textOf(widget.data['timeLabel']),
                                image: textOf(widget.data['image']),
                                // optional coordinates for the map preview
                                lat: (widget.data['lat'] as num?)?.toDouble(),
                                lng: (widget.data['lng'] as num?)?.toDouble(),
                              ),
                            ),
                          );
                        },
                        child: infoCard(
                          Icons.location_on,
                          'Location',
                          textOf(widget.data['location']),
                          false,
                        ),
                      ),

                      const SizedBox(height: 20),

                      // about
                      const Text(
                        'About this event',
                        style: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        textOf(widget.data['description']),
                        style: const TextStyle(
                            color: AppColors.greyText,
                            fontSize: 14,
                            height: 1.5),
                      ),

                      const SizedBox(height: 90),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),

      // bottom button
      bottomSheet: Container(
        color: Colors.white,
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 20),
        child: loading
            ? const SizedBox.shrink()
            : SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30),
                    ),
                  ),
                  onPressed: alreadyRegistered ? null : registerNow,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        alreadyRegistered
                            ? 'Already registered'
                            : 'Register now',
                        style: TextStyle(
                          color: alreadyRegistered
                              ? AppColors.greyText
                              : Colors.white,
                          fontSize: 16,
                        ),
                      ),
                      if (!alreadyRegistered) ...[
                        const SizedBox(width: 8),
                        const Icon(Icons.arrow_forward,
                            color: Colors.white, size: 18),
                      ],
                    ],
                  ),
                ),
              ),
      ),
    );
  }

  // one info card (date, time, location)
  Widget infoCard(IconData icon, String label, String value, bool red) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF5F5F5),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: red ? AppColors.primary : Colors.white,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon,
                color: red ? Colors.white : Colors.black, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                      color: AppColors.greyText, fontSize: 11),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: const TextStyle(
                      fontSize: 14, fontWeight: FontWeight.w500),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
