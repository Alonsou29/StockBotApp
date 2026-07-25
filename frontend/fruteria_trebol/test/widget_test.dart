import 'package:flutter_test/flutter_test.dart';
import 'package:fruteria_trebol/main.dart';

void main() {
  testWidgets('App launches and shows home screen', (WidgetTester tester) async {
    await tester.pumpWidget(const MyApp());
    await tester.pumpAndSettle();

    expect(find.text('Fruteria El Trebol'), findsOneWidget);
    expect(find.text('Hacer lista de hoy'), findsOneWidget);
    expect(find.text('Ver historial'), findsOneWidget);
  });
}
