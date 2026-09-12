import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mispar/src/shared/widgets/empty_state.dart';

void main() {
  testWidgets('EmptyState mostra titulo e mensagem', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: EmptyState(
          icon: Icons.event_available_outlined,
          title: 'Nenhum horario marcado',
          message: 'Os agendamentos aparecem aqui.',
        ),
      ),
    );

    expect(find.text('Nenhum horario marcado'), findsOneWidget);
    expect(find.text('Os agendamentos aparecem aqui.'), findsOneWidget);
  });
}
