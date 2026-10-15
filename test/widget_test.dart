import 'package:flutter_test/flutter_test.dart';

import 'package:eventhub/helpers.dart';

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
}
