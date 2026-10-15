// small helpers used in the app

// ------------------------------------------------------------
// SAFE readers for the event fields
// Firestore fields can be missing or malformed (e.g. when an
// event is added by hand), so these never throw — they fall
// back to an empty string instead of crashing the screen.
// ------------------------------------------------------------

// "1:00 PM - 3:00 PM" -> "1:00 PM". Empty string if missing.
String timeStart(dynamic timeLabel) {
  String value = (timeLabel ?? '').toString().trim();
  if (value.isEmpty) return '';
  return value.split(' - ')[0].trim();
}

// "OCT 28" -> "OCT". Empty string if missing.
String dateMonth(dynamic dateLabel) {
  List<String> parts = (dateLabel ?? '').toString().trim().split(' ');
  return parts.first.trim();
}

// "OCT 28" -> "28". Empty string if missing.
String dateDay(dynamic dateLabel) {
  List<String> parts = (dateLabel ?? '').toString().trim().split(' ');
  if (parts.length < 2) return '';
  return parts[1].trim();
}

// read a field safely as text (null becomes an empty string)
String textOf(dynamic value) => (value ?? '').toString();

// "how long ago" text for a notification timestamp
// (example: "just now", "12 min ago", "3 h ago", "2 d ago", "OCT 05")
String timeAgo(DateTime time) {
  Duration diff = DateTime.now().difference(time);

  if (diff.inMinutes < 1) return 'just now';
  if (diff.inMinutes < 60) return '${diff.inMinutes} min ago';
  if (diff.inHours < 24) return '${diff.inHours} h ago';
  if (diff.inDays < 7) return '${diff.inDays} d ago';

  // older than a week — show the short date instead
  List<String> months = [
    'JAN', 'FEB', 'MAR', 'APR', 'MAY', 'JUN',
    'JUL', 'AUG', 'SEP', 'OCT', 'NOV', 'DEC'
  ];
  String day = time.day.toString().padLeft(2, '0');
  return '${months[time.month - 1]} $day';
}

// ------------------------------------------------------------
// READABLE DOCUMENT IDS
// ------------------------------------------------------------

// turn any title into a clean document id
// "Research Congress 2026" -> "research-congress-2026"
String slugify(String text) {
  String slug = text.toLowerCase().trim();
  slug = slug.replaceAll(RegExp(r'[^a-z0-9\s]'), ' '); // drop punctuation
  slug = slug.replaceAll(RegExp(r'\s+'), '-'); // spaces become hyphens
  slug = slug.replaceAll(RegExp(r'-{2,}'), '-'); // no double hyphens
  slug = slug.replaceAll(RegExp(r'^-+|-+$'), ''); // no hyphen on the edges
  return slug.isEmpty ? 'item' : slug; // never empty
}

// a readable time stamp for ids (example: "2026-10-15-153012")
String idStamp(DateTime time) {
  String two(int n) => n.toString().padLeft(2, '0');
  return '${time.year}-${two(time.month)}-${two(time.day)}-'
      '${two(time.hour)}${two(time.minute)}${two(time.second)}';
}

// convert the dateLabel (example: "OCT 28") to a real date
DateTime getEventDate(String? dateLabel) {
  List<String> months = [
    'JAN', 'FEB', 'MAR', 'APR', 'MAY', 'JUN',
    'JUL', 'AUG', 'SEP', 'OCT', 'NOV', 'DEC'
  ];

  List<String> parts = (dateLabel ?? '').trim().split(' '); // OCT 28
  if (parts.length < 2) return DateTime.now(); // fallback

  int month = months.indexOf(parts[0].toUpperCase()) + 1;
  int day = int.tryParse(parts[1]) ?? 1;
  if (month < 1) month = DateTime.now().month; // unknown month

  return DateTime(DateTime.now().year, month, day);
}

// convert the start of the timeLabel (example: "1:00 PM") to hours and minutes
DateTime getEventTime(String? dateLabel, String? timeLabel) {
  DateTime date = getEventDate(dateLabel);

  // example: "1:00 PM - 3:00 PM" -> "1:00 PM"
  String startTime = timeStart(timeLabel);
  if (startTime.isEmpty) return date; // fallback: midnight of the day

  List<String> timeParts = startTime.split(' '); // [1:00, PM]
  List<String> hourMinute = timeParts[0].split(':'); // [1, 00]
  if (hourMinute.length < 2) return date; // fallback

  int hour = int.tryParse(hourMinute[0]) ?? 0;
  int minute = int.tryParse(hourMinute[1]) ?? 0;
  String meridiem = timeParts.length > 1 ? timeParts[1].toUpperCase() : 'AM';

  if (meridiem == 'PM' && hour != 12) hour += 12;
  if (meridiem == 'AM' && hour == 12) hour = 0;

  return DateTime(date.year, date.month, date.day, hour, minute);
}
