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
  //   users           khimcabatingan03@gmail.com
  //
  // (notifications are NOT stored here anymore — they stay on the
  //  device, see services/notification_store.dart)

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
    double? lat,
    double? lng,
    String? id,
  }) async {
    // readable id based on the title (example: "research-congress-2026")
    String wanted = id ?? slugify(title);
    String readable = await _uniqueId('events', wanted);

    await _db.collection('events').doc(readable).set({
      'title': title,
      'category': category,
      'dateLabel': dateLabel,
      'timeLabel': timeLabel,
      'location': location,
      'description': description,
      'image': image,
      'lat': lat, // venue coordinates (used by the map)
      'lng': lng,
      'createdAt': Timestamp.now(),
      // the filter state starts from the event's own schedule
      'status': eventStatusFor(dateLabel, timeLabel),
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

  // keep every event's stored status in line with its own end date
  // and time: "upcoming" -> "completed" once it finishes ->
  // "archived" 30 days later. Nothing is deleted — only the status
  // field changes, and only for the events that actually differ.
  Future<void> syncEventStatuses() async {
    QuerySnapshot snapshot = await _db.collection('events').get();

    WriteBatch batch = _db.batch();
    bool dirty = false;

    for (DocumentSnapshot doc in snapshot.docs) {
      Map data = doc.data() as Map;
      String wanted = eventFilterState(data);
      if (textOf(data['status']) == wanted) continue;

      batch.update(doc.reference, {'status': wanted});
      dirty = true;
    }

    if (dirty) await batch.commit();
  }

  // ------------------------------------------------------------
  // SAMPLE EVENTS — Bulacan State University, Malolos, Bulacan
  // ------------------------------------------------------------
  // These are the events the app seeds when the list is empty.
  //
  // Older versions used vague venues ("Event Hall", "CECT Auditorium")
  // which could not be found in Bulacan, so the map showed a place
  // outside the Philippines. The venues below are real places around
  // Bulacan State University (Main Campus, Brgy. Guinhawa, Malolos
  // City) and the coordinates are saved on the event itself, so the
  // map pin and the "Open in Maps" button land on the right spot.
  //
  // "id" and "oldTitle" are only used to find documents that an older
  // version already saved — they are never written to Firestore.
  static const List<Map<String, Object?>> sampleEvents = [
    {
      'id': 'tech-talk-intro-to-flutter',
      'oldTitle': 'Tech Talk: Intro to Flutter',
      'title': 'BulSU Tech Talk: Intro to Flutter',
      'category': 'Seminar',
      'dateLabel': 'OCT 28',
      'timeLabel': '1:00 PM - 3:00 PM',
      'location':
          'BulSU E-Library, Main Campus, Guinhawa, Malolos City, Bulacan',
      'description':
          'SAMPLE EVENT - a sample entry for the EventHub demo, not an '
          'official BulSU announcement. A short afternoon tech talk for '
          'students who want to start building mobile apps, held at the '
          'BulSU E-Library on the Main Campus in Malolos City.',
      'image': 'assets/images/event_tech.png',
      'lat': 14.857966, // BulSU Main Campus
      'lng': 120.813834,
    },
    {
      'id': 'inter-college-quiz-bowl',
      'oldTitle': 'Inter-College Quiz Bowl',
      'title': 'BulSU Inter-College Quiz Bowl',
      'category': 'Academic',
      'dateLabel': 'OCT 05',
      'timeLabel': '10:00 AM - 12:00 PM',
      'location':
          'BulSU Valencia Hall, Main Campus, Guinhawa, Malolos City, Bulacan',
      'description':
          'SAMPLE EVENT - a sample entry for the EventHub demo, not an '
          'official BulSU announcement. An inter-college quiz competition '
          'between the colleges of Bulacan State University, held at '
          'Valencia Hall (the university gymnasium) on the Main Campus in '
          'Malolos City. Open to all registered student participants.',
      'image': 'assets/images/event_quiz.png',
      'lat': 14.857966, // BulSU Main Campus
      'lng': 120.813834,
    },
    {
      'id': 'acoustic-night',
      'oldTitle': 'Acoustic Night',
      'title': 'BulSU Acoustic Night',
      'category': 'Entertainment',
      'dateLabel': 'OCT 14',
      'timeLabel': '6:00 PM - 9:00 PM',
      'location':
          'BulSU Activity Center, Main Campus, Guinhawa, Malolos City, Bulacan',
      'description':
          'SAMPLE EVENT - a sample entry for the EventHub demo, not an '
          'official BulSU announcement. An evening of live acoustic '
          'performances by BulSU student bands at the BulSU Activity '
          'Center on the Main Campus in Malolos City. Good music, food '
          'stalls, and a night to remember with your classmates.',
      'image': 'assets/images/event_music.png',
      'lat': 14.857966, // BulSU Main Campus
      'lng': 120.813834,
    },
    {
      'id': 'inter-college-basketball-league',
      'oldTitle': 'Inter-College Basketball League',
      'title': 'BulSU Inter-College Basketball League',
      'category': 'Sports',
      'dateLabel': 'NOV 02',
      'timeLabel': '2:00 PM - 5:00 PM',
      'location':
          'Bulacan Provincial Capitol Gymnasium, Guinhawa, Malolos City, Bulacan',
      'description':
          'SAMPLE EVENT - a sample entry for the EventHub demo, not an '
          'official BulSU announcement. The inter-college basketball '
          'games of the BulSU teams, played at the Bulacan Provincial '
          'Capitol Gymnasium in Malolos City, Bulacan. Cheer for your '
          'college team from the opening ceremony to the final tip-off.',
      'image': 'assets/images/event_sports.png',
      'lat': 14.856111, // Bulacan Provincial Capitol Gymnasium
      'lng': 120.815000,
    },
    {
      'id': 'research-congress-2026',
      'oldTitle': 'Research Congress 2026',
      'title': 'BulSU Research Congress 2026',
      'category': 'Academic',
      'dateLabel': 'SEP 30',
      'timeLabel': '8:00 AM - 11:00 AM',
      'location':
          'BulSU Pimentel Hall, Main Campus, Guinhawa, Malolos City, Bulacan',
      'description':
          'SAMPLE EVENT - a sample entry for the EventHub demo, not an '
          'official BulSU announcement. Student researchers present their '
          'completed papers and studies at the BulSU Research Congress, '
          'held at Pimentel Hall on the Main Campus in Malolos City.',
      'image': 'assets/images/event_workshop.png',
      'lat': 14.857966, // BulSU Main Campus
      'lng': 120.813834,
    },
  ];

  // add sample events one time only (so the list is not empty)
  Future<void> addSampleEvents() async {
    QuerySnapshot snapshot = await _db.collection('events').limit(1).get();
    if (snapshot.docs.isNotEmpty) return; // already has events

    for (Map<String, Object?> event in sampleEvents) {
      await addEvent(
        id: textOf(event['id']),
        title: textOf(event['title']),
        category: textOf(event['category']),
        dateLabel: textOf(event['dateLabel']),
        timeLabel: textOf(event['timeLabel']),
        location: textOf(event['location']),
        description: textOf(event['description']),
        image: textOf(event['image']),
        lat: (event['lat'] as num?)?.toDouble(),
        lng: (event['lng'] as num?)?.toDouble(),
      );
    }
  }

  // update the sample events that an older version already saved.
  // Everything happens in place: the document is only updated (never
  // created, never deleted), so no duplicate event can appear and the
  // registrations that point at it keep working.
  Future<void> _updateSampleEvents() async {
    for (Map<String, Object?> event in sampleEvents) {
      String id = textOf(event['id']);
      String oldTitle = textOf(event['oldTitle']);

      // find the saved document: by its id, or by the old title when
      // the id was changed by hand in the Firebase console
      DocumentSnapshot doc = await _db.collection('events').doc(id).get();
      if (!doc.exists) {
        QuerySnapshot found = await _db
            .collection('events')
            .where('title', isEqualTo: oldTitle)
            .get();
        if (found.docs.isEmpty) continue; // sample was removed — leave it
        doc = found.docs.first;
      }

      // the details that are out of date in older documents
      Map<String, Object?> update = {
        'title': event['title'],
        'category': event['category'],
        'location': event['location'],
        'description': event['description'],
        'lat': event['lat'],
        'lng': event['lng'],
      };

      Map data = doc.data() as Map;
      bool changed =
          update.entries.any((entry) => data[entry.key] != entry.value);
      if (!changed) continue; // already up to date (this runs every launch)

      try {
        await doc.reference.update(update);
        await _syncRegistrations(doc.id, update);
      } catch (_) {
        // could not finish this one (cancelled meanwhile or no internet)
        // — the next launch tries again, the other events still continue
      }
    }
  }

  // My Events and History keep their own copy of the event, so the
  // title and venue are refreshed there too. The registration document
  // itself (its id and its userId) is not touched at all, so My Events,
  // reminders and cancellation keep working exactly as before.
  Future<void> _syncRegistrations(
      String eventId, Map<String, Object?> update) async {
    QuerySnapshot docs = await _db
        .collection('registrations')
        .where('eventId', isEqualTo: eventId)
        .get();
    if (docs.docs.isEmpty) return;

    Map<String, Object?> copy = {
      'title': update['title'],
      'category': update['category'],
      'location': update['location'],
    };

    for (DocumentSnapshot doc in docs.docs) {
      try {
        await doc.reference.update(copy);
      } catch (_) {
        // this registration was cancelled while we were refreshing it —
        // skip it and still update the rest
      }
    }
  }

  // ------------------------------------------------------------
  // OLD NOTIFICATION DATA (no longer used)
  // ------------------------------------------------------------
  // Notifications now live on the device only (NotificationStore).
  // This wipes whatever was written to the "notifications" collection
  // before, so no notification data is kept in Firestore anymore.
  Future<void> removeStoredNotifications() async {
    QuerySnapshot snapshot =
        await _db.collection('notifications').limit(400).get();
    if (snapshot.docs.isEmpty) return; // nothing left

    WriteBatch batch = _db.batch();
    for (DocumentSnapshot doc in snapshot.docs) {
      batch.delete(doc.reference);
    }
    await batch.commit();

    // there may be more than one batch worth
    if (snapshot.docs.length == 400) {
      await removeStoredNotifications();
    }
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

    // 2) keep the eventId inside registrations working
    //    (notifications are local now and no longer live in Firestore)
    for (MapEntry<String, String> entry in renamedEvents.entries) {
      await _fixEventId('registrations', entry.key, entry.value);
    }

    // 3) the profile of the signed in student moves to the account id
    await _renameUserDocs();

    // 4) then the documents that belong to a student
    Map<String, String> nameKeys = await _nameKeys();
    await _renameRegistrations(nameKeys);

    // 5) finally give the sample events their BulSU venues and the
    //    coordinates the map needs (in place, no new documents)
    await _updateSampleEvents();
  }

  // uid -> first part of the email (from the users collection)
  Future<Map<String, String>> _nameKeys() async {
    Map<String, String> keys = {};
    QuerySnapshot users = await _db.collection('users').get();
    for (DocumentSnapshot doc in users.docs) {
      Map data = doc.data() as Map;
      String email = textOf(data['email']).toLowerCase();
      if (!email.contains('@')) continue;
      String prefix = email.split('@').first;

      // profiles are saved under the account id now, but older
      // documents still use the email address as their document id
      String uid = textOf(data['uid']);
      if (uid.isEmpty && !doc.id.contains('@')) uid = doc.id;

      if (uid.isNotEmpty) keys[uid] = prefix;
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

  // give the signed in student's profile the account id (uid) as its
  // document id (example: "khimcabatingan03@gmail.com" ->
  // "OJLzAzCaTnXzzycCHgCV7d2sPnr1") so every profile uses the same id
  // that the registrations store in userId.
  // The old document is copied over first and only removed after that,
  // so no student info is lost. The other students' profiles are moved
  // the same way the next time they sign in (AuthService).
  Future<void> _renameUserDocs() async {
    User? user = FirebaseAuth.instance.currentUser;
    if (user == null) return; // nobody is signed in

    String email = textOf(user.email).toLowerCase().trim();
    if (!email.contains('@')) return; // no email to look for

    DocumentSnapshot old = await _db.collection('users').doc(email).get();
    if (!old.exists) return; // already saved under the account id

    Map<String, dynamic> profile = Map<String, dynamic>.from(old.data() as Map);
    await _db.collection('users')
        .doc(user.uid)
        .set(profile, SetOptions(merge: true));
    await old.reference.delete();
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

  // keep the stored status in line with the event date: "completed"
  // once the event is over, "registered" while it is still upcoming.
  // Only the registrations that actually changed are written, so it
  // is safe to call this as often as wanted.
  Future<void> syncRegistrationStatuses() async {
    String uid = FirebaseAuth.instance.currentUser!.uid;
    QuerySnapshot snapshot = await _db
        .collection('registrations')
        .where('userId', isEqualTo: uid)
        .get();

    WriteBatch batch = _db.batch();
    bool dirty = false;

    for (DocumentSnapshot doc in snapshot.docs) {
      Map data = doc.data() as Map;
      String wanted =
          isEventPast(textOf(data['dateLabel']), textOf(data['timeLabel']))
              ? 'completed'
              : 'registered';

      if (textOf(data['status']) == wanted) continue;

      batch.update(doc.reference, {'status': wanted});
      dirty = true;
    }

    if (dirty) await batch.commit();
  }
}
