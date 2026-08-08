import 'package:flutter_test/flutter_test.dart';
import 'package:eppos_both/main.dart';

void main() {
  testWidgets('Photobooth app smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const EpposPhotoboothApp());
    expect(find.text('EPPOS BOOTH'), findsOneWidget);
  });
}
