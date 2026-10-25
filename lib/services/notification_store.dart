import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// one notification in the bell feed
class AppNotification {
  AppNotification({
    required this.id,
    required this.title,
    required this.body,
    this.type = 'info', // info, event, registration, cancellation, reminder
    this.eventId = '', // open this event when tapped
    this.read = false,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  final String id;
  final String title;
  final String body;
  final String type;
  final String eventId;
  bool read;
  final DateTime createdAt;

  Map<String, dynamic> toMap() => {
        'id': id,
        'title': title,
        'body': body,
        'type': type,
        'eventId': eventId,
        'read': read,
        'createdAt': createdAt.toIso8601String(),
      };

  factory AppNotification.fromMap(Map<String, dynamic> map) =>
      AppNotification(
        id: (map['id'] ?? '').toString(),
        title: (map['title'] ?? '').toString(),
        body: (map['body'] ?? '').toString(),
        type: (map['type'] ?? 'info').toString(),
        eventId: (map['eventId'] ?? '').toString(),
        read: map['read'] == true,
        createdAt: DateTime.tryParse((map['createdAt'] ?? '').toString()) ??
            DateTime.now(),
      );
}

class NotificationStore extends ChangeNotifier {
  NotificationStore._();
  static final NotificationStore instance = NotificationStore._();

  // one local list per student, so different accounts never mix
  static const String _prefix = 'in_app_notifications_';

  List<AppNotification> _items = [];
  String _loadedFor = '';
  Future<void>? _loading;
  String _loadingUid = '';

  /// newest first
  List<AppNotification> get items => List.unmodifiable(_items);

  int get unreadCount => _items.where((n) => !n.read).length;

  // load the signed in student's notifications (safe to call often)
  Future<void> ensureLoaded() async {
    final String uid = FirebaseAuth.instance.currentUser?.uid ?? '';
    if (uid.isEmpty) return;
    if (_loadedFor == uid) return;

    // another caller is already loading this student's list
    if (_loading != null && _loadingUid == uid) {
      return _loading!;
    }

    _loading = _load(uid);
    _loadingUid = uid;
    try {
      await _loading;
    } finally {
      _loading = null;
      _loadingUid = '';
    }
  }

  Future<void> _load(String uid) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final String? raw = prefs.getString('$_prefix$uid');

    List<AppNotification> loaded = [];
    if (raw != null && raw.isNotEmpty) {
      try {
        final List<dynamic> decoded = jsonDecode(raw) as List<dynamic>;
        loaded = decoded
            .map((item) =>
                AppNotification.fromMap(Map<String, dynamic>.from(item as Map)))
            .toList();
      } catch (_) {
        // broken local data — start fresh instead of crashing
        loaded = [];
      }
    }

    _items = loaded;
    _loadedFor = uid;
    _sort();
    notifyListeners();
  }

  // save one notification for the signed in student
  Future<void> add({
    required String title,
    required String body,
    String type = 'info', // info, event, registration, cancellation, reminder
    String eventId = '', // open this event when the notification is tapped
    DateTime? createdAt,
  }) async {
    await ensureLoaded();
    if (_loadedFor.isEmpty) return; // nobody is signed in

    _items.add(AppNotification(
      id: '${DateTime.now().microsecondsSinceEpoch}_${_items.length}',
      title: title,
      body: body,
      type: type,
      eventId: eventId,
      read: false,
      createdAt: createdAt,
    ));
    _sort();
    notifyListeners();
    await _save();
  }

  // read one notification (when the student opens it)
  Future<void> markRead(String id) async {
    await ensureLoaded();
    AppNotification? found;
    for (final AppNotification n in _items) {
      if (n.id == id) {
        found = n;
        break;
      }
    }
    if (found == null || found.read) return;
    found.read = true;
    notifyListeners();
    await _save();
  }

  // read every notification at once (the "Mark all read" button)
  Future<void> markAllRead() async {
    await ensureLoaded();
    bool changed = false;
    for (final AppNotification n in _items) {
      if (!n.read) {
        n.read = true;
        changed = true;
      }
    }
    if (!changed) return;
    notifyListeners();
    await _save();
  }

  // add welcome notifications one time only (so the list is not empty)
  Future<void> seedSamples() async {
    await ensureLoaded();
    if (_loadedFor.isEmpty || _items.isNotEmpty) return;

    final DateTime now = DateTime.now();
    _items.addAll([
      AppNotification(
        id: '${now.microsecondsSinceEpoch}_s1',
        title: 'Events of the week',
        body:
            'Inter-College Quiz Bowl and Acoustic Night are happening soon. Check the Home screen for details.',
        type: 'event',
        createdAt: now.subtract(const Duration(minutes: 30)),
      ),
      AppNotification(
        id: '${now.microsecondsSinceEpoch}_s2',
        title: 'New event added',
        body:
            'Research Congress 2026 is now open at the Library Function Hall. Tap to see the details.',
        type: 'event',
        createdAt: now.subtract(const Duration(hours: 5)),
      ),
      AppNotification(
        id: '${now.microsecondsSinceEpoch}_s3',
        title: 'Welcome to Eventhub',
        body: 'Your account is ready. Browse campus events and register in a tap.',
        type: 'info',
        createdAt: now.subtract(const Duration(days: 2)),
      ),
    ]);
    _sort();
    notifyListeners();
    await _save();
  }

  // forget everything in memory (called on logout — the saved lists
  // stay on the device and come back when the same student logs in)
  void reset() {
    _items = [];
    _loadedFor = '';
    _loading = null;
    _loadingUid = '';
    notifyListeners();
  }

  void _sort() {
    _items.sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }

  Future<void> _save() async {
    if (_loadedFor.isEmpty) return;
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      '$_prefix$_loadedFor',
      jsonEncode([for (final AppNotification n in _items) n.toMap()]),
    );
  }
}
