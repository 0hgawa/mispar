import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:mispar/src/core/router/app_router.dart';
import 'package:mispar/src/core/theme/app_colors.dart';
import 'package:mispar/src/shared/widgets/screen_title.dart';

/// Ajustes: o que se configura uma vez e quase nunca se mexe.
///
/// Fora da barra de abas de proposito — a barra e para o que o Marcos usa o
/// dia inteiro, e configuracao nao e isso.
class SettingsScreen extends StatelessWidget {
  const new({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: ListView(
          padding: const EdgeInsets.only(bottom: Dimens.gapLarge),
          children: [
            const ScreenTitle(title: 'Ajustes'),
            _Entry(
              icon: Symbols.content_cut_rounded,
              title: 'Catálogo e preços',
              detail: 'O que a barbearia faz e o que ela vende',
              onTap: () => context.push(Routes.services),
            ),
            _Entry(
              icon: Symbols.schedule_rounded,
              title: 'Horários e dias livres',
              detail: 'Quando a barbearia abre, e o almoço',
              onTap: () => context.push(Routes.shopHours),
            ),
            _Entry(
              icon: Symbols.notifications_active_rounded,
              title: 'Lembrete',
              detail: 'O aviso que sai sozinho antes do horário',
              onTap: () => context.push(Routes.reminder),
            ),
            _Entry(
              icon: Symbols.storefront_rounded,
              title: 'A barbearia',
              detail: 'Nome, endereço e o @ do Instagram',
              onTap: () => context.push(Routes.shop),
            ),
            _Entry(
              icon: Symbols.cloud_rounded,
              title: 'Cópia na nuvem',
              detail: 'Para não perder tudo com o celular',
              onTap: () => context.push(Routes.cloud),
            ),
            _Entry(
              icon: Symbols.payments_rounded,
              title: 'Pagamento',
              detail: 'O que a barbearia aceita receber',
              onTap: () => context.push(Routes.payments),
            ),
            _Entry(
              icon: Symbols.person_alert_rounded,
              title: 'Sumiram',
              detail: 'Quando avisar que um cliente parou de vir',
              onTap: () => context.push(Routes.driftedRule),
            ),
            _Entry(
              icon: Symbols.receipt_long_rounded,
              title: 'Tipos de despesa',
              detail: 'Onde o dinheiro da barbearia sai',
              onTap: () => context.push(Routes.expenseCategories),
            ),
          ],
        ),
      ),
    );
  }
}

class _Entry extends StatelessWidget {
  const new({
    required this.icon,
    required this.title,
    required this.detail,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String detail;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Column(
      children: [
        const Divider(
          height: 1,
          indent: Dimens.screenGutter,
          endIndent: Dimens.screenGutter,
        ),
        ListTile(
          contentPadding: const EdgeInsets.symmetric(
            horizontal: Dimens.screenGutter,
            vertical: 8,
          ),
          onTap: onTap,
          leading: Icon(icon, weight: 500, color: colors.onSurface),
          title: Text(
            title,
            style: theme.textTheme.bodyLarge?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          subtitle: Text(
            detail,
            style: theme.textTheme.bodySmall?.copyWith(
              color: colors.onSurfaceVariant,
            ),
          ),
          trailing: Icon(
            Symbols.chevron_right_rounded,
            weight: 500,
            color: colors.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}
