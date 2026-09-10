import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:marcos_barber/src/core/router/shell_scaffold.dart';
import 'package:marcos_barber/src/features/agenda/presentation/agenda_screen.dart';
import 'package:marcos_barber/src/features/booking/presentation/new_appointment_screen.dart';
import 'package:marcos_barber/src/features/clients/presentation/client_detail_screen.dart';
import 'package:marcos_barber/src/features/clients/presentation/clients_screen.dart';
import 'package:marcos_barber/src/features/clients/presentation/new_client_screen.dart';
import 'package:marcos_barber/src/features/reports/presentation/cash_screen.dart';
import 'package:marcos_barber/src/features/reports/presentation/expense_categories_screen.dart';
import 'package:marcos_barber/src/features/services/presentation/services_screen.dart';
import 'package:marcos_barber/src/features/settings/presentation/settings_screen.dart';
import 'package:marcos_barber/src/features/settings/presentation/shop_hours_screen.dart';

abstract final class Routes {
  static const agenda = '/agenda';
  static const clients = '/clientes';
  static const cash = '/caixa';

  static const newAppointment = '$agenda/marcar';
  static const newClient = '$clients/novo';

  static String clientDetail(String id) => '$clients/$id';

  static const settings = '/ajustes';
  static const services = '$settings/servicos';
  static const shopHours = '$settings/horarios';
  static const expenseCategories = '$settings/despesas';
}

final _rootNavigator = GlobalKey<NavigatorState>();

final appRouterProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    navigatorKey: _rootNavigator,
    initialLocation: Routes.agenda,
    routes: [
      // IndexedStack guarda o estado de cada aba: trocar de aba nao reconstroi
      // a lista nem perde a rolagem.
      StatefulShellRoute.indexedStack(
        builder: (context, state, shell) => ShellScaffold(shell: shell),
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: Routes.agenda,
                builder: (context, state) => const AgendaScreen(),
                routes: [
                  GoRoute(
                    path: 'marcar',
                    // Tela cheia: marcar e uma tarefa, nao um detalhe da lista.
                    parentNavigatorKey: _rootNavigator,
                    builder: (context, state) => const NewAppointmentScreen(),
                  ),
                ],
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: Routes.clients,
                builder: (context, state) => const ClientsScreen(),
                routes: [
                  // Antes de ':id', senao "novo" seria lido como um id.
                  GoRoute(
                    path: 'novo',
                    parentNavigatorKey: _rootNavigator,
                    builder: (context, state) => const NewClientScreen(),
                  ),
                  // Filha da aba: a ficha abre por cima e a barra continua la.
                  GoRoute(
                    path: ':id',
                    builder: (context, state) => ClientDetailScreen(
                      clientId: state.pathParameters['id']!,
                    ),
                  ),
                ],
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: Routes.cash,
                builder: (context, state) => const CashScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: Routes.settings,
                builder: (context, state) => const SettingsScreen(),
                routes: [
                  // Filha da aba: a barra continua visivel.
                  GoRoute(
                    path: 'servicos',
                    builder: (context, state) => const ServicesScreen(),
                  ),
                  GoRoute(
                    path: 'horarios',
                    builder: (context, state) => const ShopHoursScreen(),
                  ),
                  GoRoute(
                    path: 'despesas',
                    builder: (context, state) =>
                        const ExpenseCategoriesScreen(),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    ],
  );
});
