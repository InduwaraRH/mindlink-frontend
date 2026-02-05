import 'package:flutter_test/flutter_test.dart';

import 'package:mindlink_app/main.dart'; // Imports your new MindLinkApp

void main() {
  testWidgets('Login screen smoke test', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const MindLinkApp());

    // Verify that our app title 'MindLink' shows up.
    expect(find.text('MindLink'), findsOneWidget);

    // Verify that the 'LOGIN' button is on the screen.
    expect(find.text('LOGIN'), findsOneWidget);
    
    // Verify we DON'T see the old counter '0' anymore.
    expect(find.text('0'), findsNothing);
  });
}