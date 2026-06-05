import 'package:flutter_test/flutter_test.dart';

import 'package:app_bingo/main.dart';

void main() {
  testWidgets('Bingo app smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const BingoApp());

    // Verifica que la pantalla de inicio se carga correctamente
    expect(find.text('BINGO'), findsOneWidget);
    expect(find.text('Modo Automático'), findsOneWidget);
    expect(find.text('Modo Manual'), findsOneWidget);
  });
}
