import 'package:flutter_test/flutter_test.dart';

import 'package:hero_fighter/main.dart';

void main() {
  testWidgets('App loads main menu', (WidgetTester tester) async {
    await tester.pumpWidget(const HeroFighterApp());
    // Main menu should show the title
    expect(find.text('HERO FIGHTER'), findsOneWidget);
  });
}
