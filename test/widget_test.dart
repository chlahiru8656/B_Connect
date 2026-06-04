import 'package:flutter_test/flutter_test.dart';
import 'package:ble_app/main.dart';

void main() {
  testWidgets('BLE Beacon App smoke test', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const BleBeaconApp());

    // Verify that the dashboard header is present.
    expect(find.text('DIGITAL ID BADGE'), findsOneWidget);
  });
}
