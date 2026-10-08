import 'package:flutter_test/flutter_test.dart';
import 'package:meer_luxury_flutter/main.dart';

void main() {
  testWidgets('Meer Luxury app loads', (WidgetTester tester) async {
    await tester.pumpWidget(const MeerLuxuryApp());

    expect(find.text('MEER'), findsOneWidget);
    expect(find.text('LUXURY COLLECTION'), findsOneWidget);
  });
}