import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../helpers.dart';

class FirestoreService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // ------------------------------------------------------------
  // READABLE DOCUMENT IDS
  // ------------------------------------------------------------
  // Firestore makes random ids by itself (example: PwMP3KjAYVodyUiijI0Ee).
  // Instead, every document we create gets a name that is easy to
  // understand in the Firebase console:
  //
  //   events          research-congress-2026
  //   registrations   research-congress-2026__khimcabatingan03
  //   notifications   khimcabatingan03_registration-confirmed_2026-10-15-153012
  //   users           khimcabatingan03@gmail.com

  // the readable part that identifies the student
  // (first part of the email, or a piece of the account id)
  String _userKey() {
    User? user = FirebaseAuth.instance.currentUser;
    String email = textOf(user?.email).toLowerCase();
    if (email.contains('@')) return email.split('@').first;
    return _shortId(textOf(user?.uid));
  }

  // the last 6 characters of a long id (used when there is no email)
  String _shortId(String id) =>
      id.length > 6 ? id.substring(id.length - 6) : id;

  // find a free name: "wanted", then "wanted-2", "wanted-3"...
  Future<String> _uniqueId(String collection, String wanted) async {
    String id = wanted;
    int count = 2;
    while (await _db.collection(collection).doc(id).get().then((d) => d.exists)) {
      id = '$wanted-$count';
      count++;
    }
    return id;
  }

  // an id is "clean" when it is already in the readable style
  // (random Firestore ids always contain capital letters)
  bool _isCleanId(String id) => !id.contains(RegExp(r'[A-Z]'));

  // ------------------------------------------------------------
  // EVENTS
  // ------------------------------------------------------------

  // get all events (ordered by date)
  Stream<QuerySnapshot> getEvents() {
    return _db.collection('events').orderBy('createdAt').snapshots();
  }

  // get events of one category
  Stream<QuerySnapshot> getEventsByCategory(String category) {
    return _db
        .collection('events')
        .where('category', isEqualTo: category)
        .snapshots();
  }

  // add an event (used for the sample events on first run)
  Future<void> addEvent({
    required String title,
    required String category,
    required String dateLabel,
    required String timeLabel,
    required String location,
    required String description,
    required String image,
  }) async {
    // readable id based on the title (example: "research-congress-2026")
    String id = await _uniqueId('events', slugify(title));

    await _db.collection('events').doc(id).set({
      'title': title,
      'category': category,
      'dateLabel': dateLabel,
      'timeLabel': timeLabel,
      'location': location,
      'description': description,
      'image': image,
      'createdAt': Timestamp.now(),
    });
  }

  // get one event (used when a notification about it is tapped)
  Future<DocumentSnapshot> getEvent(String eventId) {
    return _db.collection('events').doc(eventId).get();
  }

  // update an event
  Future<void> updateEvent(String eventId, String title) async {
    await _db.collection('events').doc(eventId).update({'title': title});
  }

  // delete an event
  Future<void> deleteEvent(String eventId) async {
    await _db.collection('events').doc(eventId).delete();
  }

  // add sample events one time only (so the list is not empty)
  Future<void> addSampleEvents() async {
    QuerySnapshot snapshot = await _db.collection('events').limit(1).get();
    if (snapshot.docs.isNotEmpty) return; // already has events

    await addEvent(
      title: 'Tech Talk: Intro to Flutter',
      category: 'Seminar',
      dateLabel: 'OCT 28',
      timeLabel: '1:00 PM - 3:00 PM',
      location: 'CECT Auditorium',
      description:
          'Learn how to build beautiful, high-performance mobile apps with Flutter. This session covers widgets, layouts, navigation, and state management for your first cross-platform app.',
      image: 'assets/images/event_tech.png',
    );
    await addEvent(
      title: 'Inter-College Quiz Bowl',
      category: 'Academic',
      dateLabel: 'OCT 05',
      timeLabel: '10:00 AM - 12:00 PM',
      location: 'Event Hall',
      description:
          'A friendly academic competition between colleges. Show your mastery in general education, major courses, and current events. Open to all registered student participants.',
      image: 'assets/images/event_quiz.png',
    );
    await addEvent(
      title: 'Acoustic Night',
      category: 'Entertainment',
      dateLabel: 'OCT 14',
      timeLabel: '6:00 PM - 9:00 PM',
      location: 'Event Hall',
      description:
          'An evening of live acoustic performances from student bands and solo artists. Enjoy good music, food stalls, and a night to remember with your classmates.',
      image: 'assets/images/event_music.png',
    );
    await addEvent(
      title: 'Inter-College Basketball League',
      category: 'Sports',
      dateLabel: 'NOV 02',
      timeLabel: '2:00 PM - 5:00 PM',
      location: 'Covered Court',
      description:
          'Cheer for your college team in the annual basketball league. Games start at 2:00 PM with the opening ceremony before the first tip-off.',
      image: 'assets/images/event_sports.png',
    );
    await addEvent(
      title: 'Research Congress 2026',
      category: 'Academic',
      dateLabel: 'SEP 30',
      timeLabel: '8:00 AM - 11:00 AM',
      location: 'Library Function Hall',
      description:
          'Student researchers present their completed papers and studies. Attend the congress to learn new research methods and techniques from your fellow students.',
      image: 'assets/images/event_workshop.png',
    );
  }

  // ------------------------------------------------------------
  // NOTIFICATIONS
  // ------------------------------------------------------------

  // get the notifications for the logged in student
  // (sorted newest first here because Firestore orders are done
  //  in the screen after reading them all)
  Stream<QuerySnapshot> getMyNotifications() {
    String uid = FirebaseAuth.instance.currentUser!.uid;
    return _db
        .collection('notifications')
        .where('userId', isEqualTo: uid)
        .snapshots();
  }

  // save one notification for the logged in student
  Future<void> addNotification({
    required String title,
    required String body,
    String type = 'info', // info, event, registration, cancellation, reminder
    String eventId = '', // open this event when the notification is tapped
    DateTime? createdAt, // only used for the sample notifications
  }) async {
    String uid = FirebaseAuth.instance.currentUser!.uid;

    // readable id: student + message + time
    // (example: "khimcabatingan03_registration-confirmed_2026-10-15-153012")
    DateTime when = createdAt ?? DateTime.now();
    String wanted =
        '${_userKey()}_${slugify(title)}_${idStamp(when)}';
    String id = await _uniqueId('notifications', wanted);

    await _db.collection('notifications').doc(id).set({
      'userId': uid,
      'title': title,
      'body': body,
      'type': type,
      'eventId': eventId,
      'read': false,
      'createdAt': Timestamp.fromDate(when),
    });
  }

  // read one notification (when the student opens it)
  Future<void> markNotificationRead(String notificationId) async {
    await _db
        .collection('notifications')
        .doc(notificationId)
        .update({'read': true});
  }

  // read every notification at once (the "Mark all read" button)
  Future<void> markAllNotificationsRead() async {
    String uid = FirebaseAuth.instance.currentUser!.uid;
    QuerySnapshot snapshot = await _db
        .collection('notifications')
        .where('userId', isEqualTo: uid)
        .where('read', isEqualTo: false)
        .get();

    WriteBatch batch = _db.batch();
    for (DocumentSnapshot doc in snapshot.docs) {
      batch.update(doc.reference, {'read': true});
    }
    await batch.commit();
  }

  // add welcome notifications one time only (so the list is not empty)
  Future<void> addSampleNotifications() async {
    String uid = FirebaseAuth.instance.currentUser!.uid;
    QuerySnapshot snapshot = await _db
        .collection('notifications')
        .where('userId', isEqualTo: uid)
        .limit(1)
        .get();
    if (snapshot.docs.isNotEmpty) return; // already has notifications

    DateTime now = DateTime.now();
    await addNotification(
      title: 'Events of the week',
      body:
          'Inter-College Quiz Bowl and Acoustic Night are happening soon. Check the Home screen for details.',
      type: 'event',
      createdAt: now.subtract(const Duration(minutes: 30)),
    );
    await addNotification(
      title: 'New event added',
      body:
          'Research Congress 2026 is now open at the Library Function Hall. Tap to see the details.',
      type: 'event',
      createdAt: now.subtract(const Duration(hours: 5)),
    );
    await addNotification(
      title: 'Welcome to Eventhub',
      body:
          'Your account is ready. Browse campus events and register in a tap.',
      type: 'info',
      createdAt: now.subtract(const Duration(days: 2)),
    );
  }

  // ------------------------------------------------------------
  // ONE TIME CLEAN-UP OF OLD RANDOM IDS
  // ------------------------------------------------------------
  // Safe to run on every launch: it only touches documents whose id
  // is still a random Firestore id, so it never loops forever.
  // Every "move" is done with one batch (write + delete together),
  // so a document can never be lost or duplicated halfway.
  Future<void> makeIdsReadable() async {
    // 1) events first — other collections point at them
    Map<String, String> renamedEvents = await _renameEvents();

    // 2) keep the eventId inside registrations / notifications working
    for (MapEntry<String, String> entry in renamedEvents.entries) {
      await _fixEventId('registrations', entry.key, entry.value);
      await _fixEventId('notifications', entry.key, entry.value);
    }

    // 3) then the documents that belong to a student
    Map<String, String> nameKeys = await _nameKeys();
    await _renameRegistrations(nameKeys);
    await _renameNotifications(nameKeys);
    await _renameUserDocs();
  }

  // uid -> first part of the email (from the users collection)
  Future<Map<String, String>> _nameKeys() async {
    Map<String, String> keys = {};
    QuerySnapshot users = await _db.collection('users').get();
    for (DocumentSnapshot doc in users.docs) {
      String email = textOf((doc.data() as Map)['email']).toLowerCase();
      if (email.contains('@')) {
        keys[doc.id] = email.split('@').first;
      }
    }
    return keys;
  }

  // give every old event its title as the id, and remember old -> new
  Future<Map<String, String>> _renameEvents() async {
    Map<String, String> renamed = {};
    QuerySnapshot events = await _db.collection('events').get();

    for (DocumentSnapshot doc in events.docs) {
      if (_isCleanId(doc.id)) continue; // already readable

      Map data = doc.data() as Map;
      String newId = await _uniqueId('events', slugify(textOf(data['title'])));

      WriteBatch batch = _db.batch();
      batch.set(_db.collection('events').doc(newId), data);
      batch.delete(doc.reference);
      await batch.commit();

      renamed[doc.id] = newId;
    }
    return renamed;
  }

  // point registrations / notifications at the new event id
  Future<void> _fixEventId(
      String collection, String oldId, String newId) async {
    QuerySnapshot docs = await _db
        .collection(collection)
        .where('eventId', isEqualTo: oldId)
        .get();
    if (docs.docs.isEmpty) return;

    WriteBatch batch = _db.batch();
    for (DocumentSnapshot doc in docs.docs) {
      batch.update(doc.reference, {'eventId': newId});
    }
    await batch.commit();
  }

  // old registrations -> "event-name__student"
  Future<void> _renameRegistrations(Map<String, String> nameKeys) async {
    QuerySnapshot docs = await _db.collection('registrations').get();

    for (DocumentSnapshot doc in docs.docs) {
      if (_isCleanId(doc.id)) continue;

      Map data = doc.data() as Map;
      String uid = textOf(data['userId']);
      String key = nameKeys[uid] ?? _shortId(uid);
      String newId = await _uniqueId(
          'registrations', '${slugify(textOf(data['title']))}__$key');

      WriteBatch batch = _db.batch();
      batch.set(_db.collection('registrations').doc(newId), data);
      batch.delete(doc.reference);
      await batch.commit();
    }
  }

  // old notifications -> "student_message_2026-10-15-153012"
  Future<void> _renameNotifications(Map<String, String> nameKeys) async {
    QuerySnapshot docs = await _db.collection('notifications').get();

    for (DocumentSnapshot doc in docs.docs) {
      if (_isCleanId(doc.id)) continue;

      Map data = doc.data() as Map;
      String uid = textOf(data['userId']);
      String key = nameKeys[uid] ?? _shortId(uid);
      dynamic created = data['createdAt'];
      DateTime when =
          created is Timestamp ? created.toDate() : DateTime.now();
      String newId = await _uniqueId(
          'notifications',
          '${key}_${slugify(textOf(data['title']))}_${idStamp(when)}');

      WriteBatch batch = _db.batch();
      batch.set(_db.collection('notifications').doc(newId), data);
      batch.delete(doc.reference);
      await batch.commit();
    }
  }

  // give every user document the student email as the readable id
  // (example: "UHGRCT2Vgjdz1X0XVU0Aq8Z01du2" -> "khimcabatingan03@gmail.com")
  Future<void> _renameUserDocs() async {
    QuerySnapshot users = await _db.collection('users').get();

    for (DocumentSnapshot doc in users.docs) {
      Map data = doc.data() as Map;
      String email = textOf(data['email']).toLowerCase().trim();
      if (!email.contains('@')) continue; // no email to use as the name
      if (doc.id == email) continue; // already readable

      WriteBatch batch = _db.batch();
      batch.set(_db.collection('users').doc(email), data);
      batch.delete(doc.reference);
      await batch.commit();
    }
  }

  // ------------------------------------------------------------
  // REGISTRATIONS
  // ------------------------------------------------------------

  // get the events the student registered for
  Stream<QuerySnapshot> getMyRegistrations() {
    String uid = FirebaseAuth.instance.currentUser!.uid;
    return _db
        .collection('registrations')
        .where('userId', isEqualTo: uid)
        .snapshots();
  }

  // register to an event
  Future<void> registerToEvent({
    required String eventId,
    required String title,
    required String category,
    required String dateLabel,
    required String timeLabel,
    required String location,
    required String image,
    required bool reminderOn,
  }) async {
    String uid = FirebaseAuth.instance.currentUser!.uid;

    // readable id: event name + student
    // (example: "research-congress-2026__khimcabatingan03")
    String wanted = '${slugify(title)}__${_userKey()}';
    String id = wanted;

    // if that name already belongs to another student, add a short tail
    DocumentSnapshot existing =
        await _db.collection('registrations').doc(id).get();
    if (existing.exists &&
        textOf((existing.data() as Map)['userId']) != uid) {
      id = '$wanted-${_shortId(uid)}';
    }

    await _db.collection('registrations').doc(id).set({
      'userId': uid,
      'eventId': eventId,
      'title': title,
      'category': category,
      'dateLabel': dateLabel,
      'timeLabel': timeLabel,
      'location': location,
      'image': image,
      'reminderOn': reminderOn,
      'status': 'registered',
      'registeredAt': Timestamp.now(),
    });
  }

  // check if the student already registered to an event
  Future<bool> isRegistered(String eventId) async {
    String uid = FirebaseAuth.instance.currentUser!.uid;
    QuerySnapshot snapshot = await _db
        .collection('registrations')
        .where('userId', isEqualTo: uid)
        .where('eventId', isEqualTo: eventId)
        .get();
    return snapshot.docs.isNotEmpty;
  }

  // update the reminder switch
  Future<void> setReminder(String registrationId, bool value) async {
    await _db
        .collection('registrations')
        .doc(registrationId)
        .update({'reminderOn': value});
  }

  // mark a registration as completed (after the event date)
  Future<void> markCompleted(String registrationId) async {
    await _db
        .collection('registrations')
        .doc(registrationId)
        .update({'status': 'completed'});
  }

  // cancel registration (delete)
  Future<void> cancelRegistration(String registrationId) async {
    await _db.collection('registrations').doc(registrationId).delete();
  }
}
