import 'package:flutter_test/flutter_test.dart';

import 'package:eventhub/helpers.dart';

// "OCT 28" style label for a given date
String labelFor(DateTime date) {
  const months = [
    'JAN', 'FEB', 'MAR', 'APR', 'MAY', 'JUN',
    'JUL', 'AUG', 'SEP', 'OCT', 'NOV', 'DEC'
  ];
  String day = date.day.toString().padLeft(2, '0');
  return '${months[date.month - 1]} $day';
}

void main() {
  test('convert dateLabel to a real date', () {
    DateTime date = getEventDate('OCT 28');
    expect(date.day, 28);
    expect(date.month, 10);
  });

  test('convert timeLabel to hours and minutes', () {
    DateTime time = getEventTime('OCT 28', '1:00 PM - 3:00 PM');
    expect(time.hour, 13);
    expect(time.minute, 0);
  });

  test('timeEnd takes the end of the range', () {
    expect(timeEnd('1:00 PM - 3:00 PM'), '3:00 PM');
    expect(timeEnd('3:00 PM'), '3:00 PM'); // a single time is its own end
    expect(timeEnd(null), '');
  });

  test('an event that already finished is past', () {
    // today, ended one minute after midnight
    String today = labelFor(DateTime.now());
    expect(isEventPast(today, '12:00 AM - 12:01 AM'), true);
  });

  test('an upcoming event is not past', () {
    // today, ends just before midnight
    String today = labelFor(DateTime.now());
    expect(isEventPast(today, '12:00 PM - 11:59 PM'), false);
  });

  test('registration knows which tab it belongs to', () {
    String today = labelFor(DateTime.now());

    // finished event -> Event History
    expect(
        isCompletedRegistration({
          'dateLabel': today,
          'timeLabel': '12:00 AM - 12:01 AM',
          'status': 'registered',
        }),
        true);

    // registration saved before the status field existed
    expect(
        isCompletedRegistration({
          'dateLabel': today,
          'timeLabel': '12:00 AM - 12:01 AM',
        }),
        true);

    // still upcoming -> My Events
    expect(
        isCompletedRegistration({
          'dateLabel': today,
          'timeLabel': '12:00 PM - 11:59 PM',
          'status': 'registered',
        }),
        false);

    // "completed" status is sticky
    expect(
        isCompletedRegistration({
          'dateLabel': today,
          'timeLabel': '12:00 PM - 11:59 PM',
          'status': 'completed',
        }),
        true);
  });

  test('a completed event never sorts into the future', () {
    // dateLabel has no year: a finished event whose guessed date is
    // still ahead of us must belong to last year
    DateTime end = finishedAt('DEC 15', '1:00 PM - 3:00 PM');
    if (end.isAfter(DateTime.now())) {
      expect(end.year, DateTime.now().year - 1);
    }
  });

  test('event filter state follows its own end date and time', () {
    final DateTime now = DateTime.now();

    // still ahead of us -> upcoming
    final DateTime future = now.add(const Duration(days: 5));
    if (future.year == now.year) {
      expect(eventStatusFor(labelFor(future), '10:00 AM - 12:00 PM'),
          'upcoming');
    }

    // finished less than 30 days ago -> completed
    final DateTime finished = now.subtract(const Duration(days: 5));
    if (finished.year == now.year) {
      expect(eventStatusFor(labelFor(finished), '10:00 AM - 12:00 PM'),
          'completed');
    }

    // finished 30 or more days ago -> archived
    final DateTime older = now.subtract(const Duration(days: 40));
    if (older.year == now.year) {
      expect(eventStatusFor(labelFor(older), '10:00 AM - 12:00 PM'),
          'archived');
    }
  });

  test('event documents read their filter state too', () {
    final DateTime future = DateTime.now().add(const Duration(days: 5));
    if (future.year == DateTime.now().year) {
      expect(
          eventFilterState({
            'dateLabel': labelFor(future),
            'timeLabel': '10:00 AM - 12:00 PM',
          }),
          'upcoming');
      expect(
          isUpcomingEvent({
            'dateLabel': labelFor(future),
            'timeLabel': '10:00 AM - 12:00 PM',
          }),
          true);
    }
  });
}
