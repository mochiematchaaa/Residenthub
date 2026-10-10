import 'package:flutter_test/flutter_test.dart';

import 'package:residenthub_dashboard/main.dart';

void main() {
  testWidgets('shows the sign-in screen first', (tester) async {
    await tester.pumpWidget(const ResidentHubApp());
    await tester.pump();
    expect(find.text('Welcome back!'), findsOneWidget);
    expect(find.text('Continue'), findsOneWidget);
  });
}
