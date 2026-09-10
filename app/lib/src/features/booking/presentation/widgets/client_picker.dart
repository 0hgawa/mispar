import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:marcos_barber/src/core/theme/app_colors.dart';
import 'package:marcos_barber/src/features/booking/presentation/new_appointment_view_model.dart';
import 'package:marcos_barber/src/features/clients/domain/client_summary.dart';
import 'package:marcos_barber/src/features/clients/presentation/clients_view_model.dart';
import 'package:marcos_barber/src/shared/widgets/app_card.dart';
import 'package:material_symbols_icons/symbols.dart';

/// Escolhe quem vai sentar na cadeira.
///
/// Um campo so: digita o nome e, se a pessoa ja existe, ela aparece; se nao
/// existe, o proprio texto vira um cliente novo. Sem escolher antes entre
/// "buscar" e "cadastrar" — na hora do atendimento ninguem sabe qual dos dois
/// e.
///
/// Quem ja existe aparece **flutuando sobre a tela**, e nao empurrando o resto
/// para baixo: a lista de nomes e um atalho de meio segundo, e nao pode custar
/// um terco da altura do formulario. Sai assim que ele escolhe, ou quando o
/// campo perde o foco.
class ClientPicker extends ConsumerStatefulWidget {
  const new({super.key});

  @override
  ConsumerState<ClientPicker> createState() => _ClientPickerState();
}

class _ClientPickerState extends ConsumerState<ClientPicker> {
  final _name = TextEditingController();
  final _phone = TextEditingController();
  final _focus = FocusNode();
  final _anchor = LayerLink();
  final _suggestions = OverlayPortalController();

  /// O termo desta tela. Nao e o mesmo da tela de Clientes: compartilhar
  /// fazia o formulario abrir ja mostrando o que foi digitado na outra.
  String _term = '';

  @override
  void initState() {
    super.initState();
    _focus.addListener(_refresh);
  }

  @override
  void dispose() {
    _focus
      ..removeListener(_refresh)
      ..dispose();
    _name.dispose();
    _phone.dispose();
    super.dispose();
  }

  void _refresh() => setState(() {});

  void _syncNewClient() {
    ref
        .read(bookingProvider.notifier)
        .chooseClient(NewClient(name: _name.text, phone: _phone.text));
  }

  List<ClientSummary> get _matches {
    if (!_focus.hasFocus || _term.trim().length < 2) {
      return const <ClientSummary>[];
    }

    final all = ref.watch(allClientsProvider).value ?? const <ClientSummary>[];

    return [
      for (final summary in matchingClients(all, _term))
        if (summary.client.isActive) summary,
    ].take(4).toList(growable: false);
  }

  void _choose(ClientSummary summary) {
    _focus.unfocus();
    ref
        .read(bookingProvider.notifier)
        .chooseClient(ExistingClient(summary.client));
  }

  @override
  Widget build(BuildContext context) {
    final chosen = ref.watch(bookingProvider).client;

    if (chosen is ExistingClient) {
      return _ChosenCard(
        name: chosen.client.name,
        detail: chosen.client.phone,
        onClear: () {
          _name.clear();
          setState(() => _term = '');
          ref
              .read(bookingProvider.notifier)
              .chooseClient(const NewClient(name: '', phone: ''));
        },
      );
    }

    final matches = _matches;
    // O portal so abre com o que mostrar. Chamar fora do build evita mexer no
    // overlay no meio da montagem da arvore.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      matches.isEmpty ? _suggestions.hide() : _suggestions.show();
    });

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        CompositedTransformTarget(
          link: _anchor,
          child: OverlayPortal(
            controller: _suggestions,
            overlayChildBuilder: (_) => _SuggestionList(
              anchor: _anchor,
              matches: matches,
              onChoose: _choose,
            ),
            child: _Field(
              controller: _name,
              focusNode: _focus,
              hint: 'Nome do cliente',
              icon: Symbols.person_rounded,
              onChanged: (value) {
                setState(() => _term = value);
                _syncNewClient();
              },
            ),
          ),
        ),
        if (_name.text.trim().length >= 2) ...[
          const SizedBox(height: Dimens.gapSmall),
          _Field(
            controller: _phone,
            hint: 'Telefone (opcional)',
            icon: Symbols.call_rounded,
            keyboardType: TextInputType.phone,
            onChanged: (_) => _syncNewClient(),
          ),
        ],
      ],
    );
  }
}

/// Os nomes que casam, ancorados logo abaixo do campo.
class _SuggestionList extends StatelessWidget {
  const new({
    required this.anchor,
    required this.matches,
    required this.onChoose,
  });

  final LayerLink anchor;
  final List<ClientSummary> matches;
  final ValueChanged<ClientSummary> onChoose;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final width = MediaQuery.sizeOf(context).width - Dimens.screenGutter * 2;

    return Positioned(
      width: width,
      child: CompositedTransformFollower(
        link: anchor,
        targetAnchor: Alignment.bottomLeft,
        offset: const Offset(0, Dimens.gapSmall),
        child: Align(
          alignment: Alignment.topLeft,
          child: Material(
            color: Colors.transparent,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final summary in matches)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: AppCard(
                      onTap: () => onChoose(summary),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  summary.client.name,
                                  style: theme.textTheme.bodyLarge,
                                ),
                                Text(
                                  summary.client.note ??
                                      summary.usualService ??
                                      summary.client.phone,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: theme.colorScheme.onSurfaceVariant,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Icon(
                            Symbols.arrow_forward_rounded,
                            weight: 500,
                            size: 18,
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Field extends StatelessWidget {
  const new({
    required this.controller,
    required this.hint,
    required this.icon,
    required this.onChanged,
    this.focusNode,
    this.keyboardType,
  });

  final TextEditingController controller;
  final String hint;
  final IconData icon;
  final ValueChanged<String> onChanged;
  final FocusNode? focusNode;
  final TextInputType? keyboardType;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return TextField(
      controller: controller,
      focusNode: focusNode,
      onChanged: onChanged,
      keyboardType: keyboardType,
      textCapitalization: TextCapitalization.words,
      style: theme.textTheme.bodyMedium,
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: theme.textTheme.bodyMedium?.copyWith(
          color: colors.onSurfaceVariant,
        ),
        prefixIcon: Icon(icon, weight: 500, color: colors.onSurfaceVariant),
        filled: true,
        fillColor: colors.secondaryContainer,
        contentPadding: const EdgeInsets.symmetric(vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(Dimens.pillRadius),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }
}

class _ChosenCard extends StatelessWidget {
  const new({required this.name, required this.detail, required this.onClear});

  final String name;
  final String detail;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AppCard(
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: theme.textTheme.headlineSmall),
                const SizedBox(height: 2),
                Text(
                  detail,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Symbols.close_rounded, weight: 500),
            color: theme.colorScheme.onSurfaceVariant,
            tooltip: 'Trocar de cliente',
            onPressed: onClear,
          ),
        ],
      ),
    );
  }
}
