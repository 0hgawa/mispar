import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';

/// Casca do app: as quatro abas de baixo, sempre no mesmo lugar.
class ShellScaffold extends StatelessWidget {
  const new({required this.shell, super.key});

  final StatefulNavigationShell shell;

  /// Traco grosso e cantos arredondados. Contorno quando parado, glifo cheio
  /// quando selecionado — e assim que a referencia marca a aba ativa.
  static const _strokeWeight = 500.0;

  static const List<({IconData icon, String label})> _tabs = [
    (icon: Symbols.calendar_month_rounded, label: 'Agenda'),
    (icon: Symbols.group_rounded, label: 'Clientes'),
    (icon: Symbols.account_balance_wallet_rounded, label: 'Caixa'),
    (icon: Symbols.settings_rounded, label: 'Ajustes'),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // Troca de aba com um fade curto e uma subida de 8px. O IndexedStack por
      // baixo continua guardando o estado de cada aba.
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 220),
        switchInCurve: Curves.easeOutCubic,
        switchOutCurve: Curves.easeIn,
        transitionBuilder: (child, animation) => FadeTransition(
          opacity: animation,
          child: SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0, 0.012),
              end: Offset.zero,
            ).animate(animation),
            child: child,
          ),
        ),
        child: KeyedSubtree(key: ValueKey(shell.currentIndex), child: shell),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: shell.currentIndex,
        destinations: [
          for (final tab in _tabs)
            NavigationDestination(
              icon: Icon(tab.icon, weight: _strokeWeight),
              selectedIcon: Icon(tab.icon, fill: 1, weight: _strokeWeight),
              label: tab.label,
            ),
        ],
        // initialLocation: volta ao topo da aba se ela ja estiver aberta.
        onDestinationSelected: (index) =>
            shell.goBranch(index, initialLocation: index == shell.currentIndex),
      ),
    );
  }
}
