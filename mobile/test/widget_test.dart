import 'package:flutter_test/flutter_test.dart';
import 'package:inventario_mobile/main.dart';

void main() {
  testWidgets('App renders without crashing', (WidgetTester tester) async {
    await tester.pumpWidget(const InventarioApp());
    // Basic smoke test: app should render
    expect(find.byType(InventarioApp), findsOneWidget);
  });
}
