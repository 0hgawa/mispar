import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:marcos_barber/src/core/theme/app_colors.dart';
import 'package:marcos_barber/src/core/theme/status_colors.dart';
import 'package:marcos_barber/src/features/services/data/service_repository.dart';
import 'package:marcos_barber/src/features/services/domain/catalogue_kind.dart';
import 'package:marcos_barber/src/features/services/domain/service.dart';
import 'package:marcos_barber/src/shared/formatters/day_time.dart';
import 'package:marcos_barber/src/shared/formatters/text.dart';
import 'package:marcos_barber/src/shared/task_route.dart';
import 'package:marcos_barber/src/shared/widgets/app_snack.dart';
import 'package:marcos_barber/src/shared/widgets/bottom_action.dart';
import 'package:marcos_barber/src/shared/widgets/confirm.dart';
import 'package:marcos_barber/src/shared/widgets/screen_title.dart';
import 'package:marcos_barber/src/shared/widgets/segmented_toggle.dart';
import 'package:marcos_barber/src/shared/widgets/task_bar.dart';
import 'package:material_symbols_icons/symbols.dart';

/// Cadastrar ou corrigir um servico.
///
/// Duracao em pilulas e nao em campo livre: barbearia trabalha em blocos de
/// quinze minutos, e digitar "37" so criaria buraco na agenda.
class ServiceForm extends ConsumerStatefulWidget {
  const new({this.service, super.key});

  final Service? service;

  static Future<void> show(BuildContext context, {Service? service}) {
    return openTask(context, (_) => ServiceForm(service: service));
  }

  @override
  ConsumerState<ServiceForm> createState() => _ServiceFormState();
}

class _ServiceFormState extends ConsumerState<ServiceForm> {
  static const _durations = [15, 30, 45, 60, 90, 120];

  late final _name = TextEditingController(text: widget.service?.name ?? '');
  late final _price = TextEditingController(
    text: widget.service == null
        ? ''
        : (widget.service!.priceCents / 100).toStringAsFixed(0),
  );

  late int _minutes = widget.service?.duration.inMinutes ?? 30;
  late bool _requiresDeposit = widget.service?.requiresDeposit ?? false;
  late bool _isActive = widget.service?.isActive ?? true;
  late CatalogueKind _kind = widget.service?.kind ?? CatalogueKind.service;
  bool _saving = false;

  /// Quantos atendimentos usam este servico. Nulo enquanto nao chegou.
  int? _usage;

  @override
  void initState() {
    super.initState();
    final service = widget.service;
    if (service == null) return;
    unawaited(
      ref.read(serviceRepositoryProvider).usageCount(service.id).then((count) {
        if (mounted) setState(() => _usage = count);
      }),
    );
  }

  bool get _isEditing => widget.service != null;

  bool get _isValid =>
      _name.text.trim().length >= 2 && (int.tryParse(_price.text) ?? -1) >= 0;

  @override
  void dispose() {
    _name.dispose();
    _price.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: TaskBar(
        title: _isEditing ? _kind.label : 'Novo ${_kind.label.toLowerCase()}',
      ),
      body: ListView(
        padding: const EdgeInsets.only(bottom: Dimens.gapLarge),
        children: [
          // So no cadastro: o tipo decide o formulario inteiro, e trocar
          // depois de ter historico transformaria venda em atendimento.
          if (!_isEditing)
            Padding(
              padding: const EdgeInsets.fromLTRB(
                Dimens.screenGutter,
                0,
                Dimens.screenGutter,
                Dimens.gapSmall,
              ),
              child: SegmentedToggle(
                options: [
                  for (final kind in CatalogueKind.values)
                    (value: kind, label: kind.label),
                ],
                selected: _kind,
                onSelect: (kind) => setState(() => _kind = kind),
              ),
            ),
          const SectionLabel('Nome e preço'),
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: Dimens.screenGutter,
            ),
            child: Column(
              children: [
                _Field(
                  controller: _name,
                  hint: _kind == CatalogueKind.product
                      ? 'Pomada, óleo de barba, shampoo…'
                      : 'Corte, Barba, Degradê…',
                  icon: _kind == CatalogueKind.product
                      ? Symbols.shopping_bag_rounded
                      : Symbols.content_cut_rounded,
                  autofocus: !_isEditing,
                  capitalize: true,
                  onChanged: (_) => setState(() {}),
                ),
                const SizedBox(height: Dimens.gapSmall),
                _Field(
                  controller: _price,
                  hint: 'Preço em reais',
                  icon: Symbols.payments_rounded,
                  keyboardType: TextInputType.number,
                  digitsOnly: true,
                  onChanged: (_) => setState(() {}),
                ),
              ],
            ),
          ),
          if (_kind == CatalogueKind.service) ...[
            const SectionLabel('Quanto tempo leva'),
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: Dimens.screenGutter,
              ),
              child: Wrap(
                spacing: Dimens.gapSmall,
                runSpacing: Dimens.gapSmall,
                children: [
                  for (final minutes in _durations)
                    ChoiceChip(
                      label: Text(formatDuration(Duration(minutes: minutes))),
                      selected: minutes == _minutes,
                      onSelected: (_) => setState(() => _minutes = minutes),
                    ),
                ],
              ),
            ),
            const SectionLabel('Regras'),
            SwitchListTile(
              contentPadding: const EdgeInsets.symmetric(
                horizontal: Dimens.screenGutter,
              ),
              value: _requiresDeposit,
              onChanged: (value) => setState(() => _requiresDeposit = value),
              title: const Text('Pede sinal'),
              subtitle: Text(
                'Serviço longo ou cliente que já faltou. Só fica confirmado '
                'quando o dinheiro entra.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ],
          if (_isEditing)
            SwitchListTile(
              contentPadding: const EdgeInsets.symmetric(
                horizontal: Dimens.screenGutter,
              ),
              value: _isActive,
              onChanged: (value) => setState(() => _isActive = value),
              title: Text(
                _kind == CatalogueKind.product ? 'À venda' : 'No cardápio',
              ),
              subtitle: Text(
                _kind == CatalogueKind.product
                    ? 'Desligado, some do lançamento — mas o histórico de '
                          'quem já comprou continua inteiro.'
                    : 'Desligado, some das opções de marcar — mas o histórico '
                          'de quem já pagou continua inteiro.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          if (_isEditing) _DeleteZone(usage: _usage, onDelete: _confirmDelete),
        ],
      ),
      bottomNavigationBar: BottomAction(
        child: FilledButton(
          onPressed: _isValid && !_saving ? _save : null,
          child: _saving
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text(_isEditing ? 'Salvar' : 'Cadastrar'),
        ),
      ),
    );
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    final name = _name.text.trim();

    try {
      // No catalogo, o nome e a identidade: dois "Corte" com precos
      // diferentes deixariam o Marcos sem saber qual escolher ao marcar.
      if (!_isEditing) {
        final clash = await ref
            .read(serviceRepositoryProvider)
            .findById(_idFrom(name));
        if (clash != null) {
          if (!mounted) return;
          setState(() => _saving = false);
          showSnack(context, 'Já existe um serviço chamado ${clash.name}.');
          return;
        }
      }

      await ref
          .read(serviceRepositoryProvider)
          .save(
            Service(
              // O id vem do nome para o robo citar o servico pelo mesmo
              // identificador que o Postgres usa. Nunca muda depois de criado.
              id: widget.service?.id ?? _idFrom(name),
              name: name,
              // Produto nasce com zero minuto: nao e um valor escolhido, e a
              // ausencia dele.
              duration: Duration(
                minutes: _kind == CatalogueKind.product ? 0 : _minutes,
              ),
              priceCents: (int.tryParse(_price.text) ?? 0) * 100,
              requiresDeposit:
                  _kind == CatalogueKind.service && _requiresDeposit,
              isActive: _isActive,
              kind: _kind,
            ),
          );

      if (!mounted) return;
      Navigator.of(context).pop();
    } on Object {
      if (!mounted) return;
      setState(() => _saving = false);
      showSnack(context, 'Não consegui salvar. Tente de novo.');
    }
  }

  Future<void> _confirmDelete() async {
    final service = widget.service!;
    final confirmed = await askToConfirm(
      context,
      title: 'Apagar serviço?',
      message:
          '${service.name} some de vez. Como ninguém usou, nada do histórico '
          'se perde.',
      confirmLabel: 'Apagar',
    );

    if (!confirmed) return;
    await ref.read(serviceRepositoryProvider).delete(service.id);

    if (!mounted) return;
    Navigator.of(context).pop();
    showSnack(context, '${service.name} apagado.');
  }

  String _idFrom(String name) =>
      normalizeForSearch(name)
          .replaceAll(RegExp('[^a-z0-9]+'), '-')
          .replaceAll(RegExp(r'^-|-$'), '');
}

class _Field extends StatelessWidget {
  const new({
    required this.controller,
    required this.hint,
    required this.icon,
    this.keyboardType,
    this.onChanged,
    this.autofocus = false,
    this.capitalize = false,
    this.digitsOnly = false,
  });

  final TextEditingController controller;
  final String hint;
  final IconData icon;
  final TextInputType? keyboardType;
  final ValueChanged<String>? onChanged;
  final bool autofocus;
  final bool capitalize;
  final bool digitsOnly;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return TextField(
      controller: controller,
      onChanged: onChanged,
      keyboardType: keyboardType,
      autofocus: autofocus,
      inputFormatters: digitsOnly
          ? [FilteringTextInputFormatter.digitsOnly]
          : null,
      textCapitalization: capitalize
          ? TextCapitalization.words
          : TextCapitalization.none,
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

/// Apagar de vez, e so quando ninguem usou.
///
/// Com atendimento atrelado o banco recusa, e mesmo que aceitasse aqueles
/// atendimentos sumiriam da agenda e do caixa — a consulta junta pelo servico
/// para pegar o nome. Nesse caso o caminho e tirar do cardapio.
class _DeleteZone extends StatelessWidget {
  const new({required this.usage, required this.onDelete});

  final int? usage;
  final Future<void> Function() onDelete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final usage = this.usage;
    if (usage == null) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        Dimens.screenGutter,
        Dimens.gapLarge,
        Dimens.screenGutter,
        0,
      ),
      child: usage > 0
          ? Text(
              usage == 1
                  ? 'Não dá para apagar: 1 atendimento usa este serviço. '
                        'Para sumir do app, desligue "No cardápio".'
                  : 'Não dá para apagar: $usage atendimentos usam este '
                        'serviço. Para sumir do app, desligue "No cardápio".',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            )
          : Align(
              alignment: Alignment.centerLeft,
              child: TextButton(
                onPressed: onDelete,
                style: TextButton.styleFrom(
                  foregroundColor: theme.status.alert,
                ),
                child: const Text('Apagar serviço'),
              ),
            ),
    );
  }
}
