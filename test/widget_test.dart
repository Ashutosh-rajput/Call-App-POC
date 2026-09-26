import 'package:flutter_test/flutter_test.dart';
import 'package:call_test/main.dart';

void main() {
  testWidgets('CallStreamingTestApp initial smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const CallStreamingTestApp());
    expect(find.text('Call Streaming Test App'), findsOneWidget);
  });
}
