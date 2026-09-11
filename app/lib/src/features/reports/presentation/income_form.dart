import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:marcos_barber/src/core/theme/app_colors.dart';
import 'package:marcos_barber/src/features/agenda/data/agenda_repository.dart';
import 'package:marcos_barber/src/features/agenda/domain/payment_method.dart';
import 'package:marcos_barber/src/features/clients/domain/client.dart';
import 'package:marcos_barber/src/features/clients/presentation/clients_view_model.dart';
import 'package:marcos_barber/src/features/services/data/service_repository.dart';
import 'package:marcos_barber/src/features/services/domain/service.dart';
import 'package:marcos_barber/src/shared/task_route.dart';
import 'package:marcos_barber/src/shared/widgets/app_sheet.dart';
import 'package:marcos_barber/src/shared/widgets/app_snack.dart';
import 'package:marcos_barber/src/shared/widgets/bottom_action.dart';
import 'package:marcos_barber/src/shared/widgets/day_button.dart';
import 'package:marcos_barber/src/shared/widgets/initials_avatar.dart';
import 'package:marcos_barber/src/shared/widgets/screen_title.dart';
import 'package:marcos_barber/src/shared/widgets/task_bar.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:uuid/uuid.dart';

final _catalogueProvider = StreamProvider<List<Service>>(
  (ref) => ref.watch(serviceRepositoryProvider).watchAll(),
);

/// Lançar um atendimento que não passou pela agenda.
///
/// Quem chega sem marcar é dinheiro que hoje entrava na gaveta e não entrava
/// no Caixa: para registrar, o Marcos teria que criar um horário no passado, e
/// a tela de marcar nem oferece horário que já passou.
///
/// O cliente é opcional de propósito. Quem aparece de surpresa quase nunca é
/// cadastrado, e exigir o nome ali faria o lançamento não acontecer — que é
/// exatamente o problema que esta tela resolve.
class IncomeForm extends ConsumerStatefulWidget {
  const new({super.key});

  static Future<void> show(BuildContext context) {
    return openTask(context, (_) => const IncomeForm());
  }

  @override
  ConsumerState<IncomeForm> createState() => _IncomeFormState();
}

class _IncomeFormState extends ConsumerState<IncomeForm> {
  final _amount = TextEditingController();

  Service? _service;
  PaymentMethod? _paidWith;
  Client? _client;
  DateTime _at = DateTime.now();
  bool _saving = false;

  /// Valor, serviço e forma de pagamento. A forma de pagamento entra na conta
  /// porque é aqui que ela é mais fácil de perder: o dinheiro já está na mão.
  bool get _isValid =>
      (int.tryParse(_amount.text) ?? 0) > 0 &&
      _service != null &&
      _paidWith != null;

  @override
  void dispose() {
    _amount.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final catalogue = ref.watch(_catalogueProvider).value ?? const <Service>[];
    final services = catalogue.where((item) => !item.isProduct).toList();
    final products = catalogue.where((item) => item.isProduct).toList();

    return Scaffold(
      appBar: const TaskBar(title: 'Lançar receita'),
      body: ListView(
        padding: const EdgeInsets.only(bottom: Dimens.gapLarge),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              Dimens.screenGutter,
              0,
              Dimens.screenGutter,
              Dimens.gapSmall,
            ),
            child: Align(
              alignment: Alignment.centerLeft,
              child: DayButton(day: _at, onTap: _pickDay),
            ),
          ),
          const SectionLabel('Quanto entrou'),
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: Dimens.screenGutter,
            ),
            child: TextField(
              controller: _amount,
              autofocus: true,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              onChanged: (_) => setState(() {}),
              style: theme.textTheme.headlineMedium?.copyWith(fontSize: 34),
              decoration: InputDecoration(
                hintText: '0',
                prefixText: r'R$ ',
                prefixStyle: theme.textTheme.headlineMedium?.copyWith(
                  fontSize: 34,
                  color: colors.onSurfaceVariant,
                ),
                hintStyle: theme.textTheme.headlineMedium?.copyWith(
                  fontSize: 34,
                  color: colors.onSurfaceVariant,
                ),
                filled: true,
                fillColor: colors.secondaryContainer,
                contentPadding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(Dimens.cardRadius),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
          SectionLabel(products.isEmpty ? 'Que serviço' : 'O que foi'),
          if (catalogue.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: Dimens.screenGutter,
              ),
              child: Text(
                'Nada no catálogo. Ajustes → Catálogo.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: colors.onSurfaceVariant,
                ),
              ),
            ),
          if (services.isNotEmpty)
            _Choices(
              items: services,
              chosen: _service,
              onChoose: _chooseService,
            ),
          // Produto so ganha titulo proprio quando existe: com o catalogo so
          // de servicos, o rotulo separaria uma lista de nada.
          if (products.isNotEmpty) ...[
            const SectionLabel('Produtos'),
            _Choices(
              items: products,
              chosen: _service,
              onChoose: _chooseService,
            ),
          ],
          const SectionLabel('Como pagou'),
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: Dimens.screenGutter,
            ),
            child: Wrap(
              spacing: Dimens.gapSmall,
              runSpacing: Dimens.gapSmall,
              children: [
                for (final method in PaymentMethod.values)
                  ChoiceChip(
                    label: Text(method.label),
                    selected: method == _paidWith,
                    onSelected: (_) => setState(() => _paidWith = method),
                  ),
              ],
            ),
          ),
          const SectionLabel('Cliente'),
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: Dimens.screenGutter,
            ),
            child: _ClientField(
              client: _client,
              onPick: _pickClient,
              onClear: () => setState(() => _client = null),
            ),
          ),
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
              : const Text('Lançar'),
        ),
      ),
    );
  }

  /// Escolher o servico ja sugere o preco de tabela — e so o sugere: quem
  /// chega sem marcar e justamente quem costuma pagar outro valor.
  void _chooseService(Service service) {
    setState(() {
      _service = service;
      if (_amount.text.isEmpty) {
        _amount.text = (service.priceCents / 100).toStringAsFixed(0);
      }
    });
  }

  Future<void> _pickDay() async {
    final now = DateTime.now();
    final chosen = await showDatePicker(
      context: context,
      initialDate: _at,
      firstDate: DateTime(now.year - 3),
      // Atendimento do futuro nao existe: ou ja aconteceu, ou e horario
      // marcado, e horario marcado se marca na Agenda.
      lastDate: DateTime(now.year, now.month, now.day),
      helpText: 'Dia do atendimento',
      cancelText: 'Voltar',
      confirmText: 'Usar',
    );
    if (chosen == null) return;
    setState(() => _at = chosen);
  }

  Future<void> _pickClient() async {
    final chosen = await showAppSheet<Client>(
      context,
      title: 'Quem foi?',
      builder: (_) => const _ClientPicker(),
    );
    if (chosen == null) return;
    setState(() => _client = chosen);
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    final service = _service!;

    try {
      await ref
          .read(agendaRepositoryProvider)
          .lance(
            id: const Uuid().v4(),
            clientId: _client?.id,
            service: service,
            at: _at,
            priceCents: (int.tryParse(_amount.text) ?? 0) * 100,
            paidWith: _paidWith!,
          );

      if (!mounted) return;
      Navigator.of(context).pop();
    } on Object {
      if (!mounted) return;
      setState(() => _saving = false);
      showSnack(context, 'Não consegui lançar. Tente de novo.');
    }
  }
}

/// Uma fileira de pilulas do catalogo.
class _Choices extends StatelessWidget {
  const new({
    required this.items,
    required this.chosen,
    required this.onChoose,
  });

  final List<Service> items;
  final Service? chosen;
  final ValueChanged<Service> onChoose;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: Dimens.screenGutter),
      child: Wrap(
        spacing: Dimens.gapSmall,
        runSpacing: Dimens.gapSmall,
        children: [
          for (final item in items)
            ChoiceChip(
              label: Text(item.name),
              selected: item.id == chosen?.id,
              onSelected: (_) => onChoose(item),
            ),
        ],
      ),
    );
  }
}

/// O cliente, quando ha um. Vazio e o estado normal, nao um erro.
class _ClientField extends StatelessWidget {
  const new({
    required this.client,
    required this.onPick,
    required this.onClear,
  });

  final Client? client;
  final VoidCallback onPick;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final client = this.client;

    if (client == null) {
      return Align(
        alignment: Alignment.centerLeft,
        child: OutlinedButton.icon(
          onPressed: onPick,
          icon: const Icon(Symbols.person_add_rounded, size: 20, weight: 500),
          label: const Text('Ligar a um cliente'),
        ),
      );
    }

    return Row(
      children: [
        InitialsAvatar(name: client.name, size: 36),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            client.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodyLarge,
          ),
        ),
        IconButton(
          onPressed: onClear,
          tooltip: 'Tirar o cliente',
          icon: Icon(
            Symbols.close_rounded,
            weight: 500,
            color: colors.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

/// A lista de clientes, com busca. Reaproveita a mesma busca da aba Clientes.
class _ClientPicker extends ConsumerStatefulWidget {
  const new();

  @override
  ConsumerState<_ClientPicker> createState() => _ClientPickerState();
}

class _ClientPickerState extends ConsumerState<_ClientPicker> {
  final _search = TextEditingController();
  String _term = '';

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final all = ref.watch(allClientsProvider).value ?? [];
    final clients = matchingClients(all, _term);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        TextField(
          controller: _search,
          autofocus: true,
          textCapitalization: TextCapitalization.words,
          onChanged: (term) => setState(() => _term = term),
          decoration: InputDecoration(
            hintText: 'Buscar por nome ou telefone',
            hintStyle: theme.textTheme.bodyMedium?.copyWith(
              color: colors.onSurfaceVariant,
            ),
            prefixIcon: Icon(
              Symbols.search_rounded,
              weight: 500,
              color: colors.onSurfaceVariant,
            ),
            filled: true,
            fillColor: colors.secondaryContainer,
            contentPadding: const EdgeInsets.symmetric(vertical: 14),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(Dimens.pillRadius),
              borderSide: BorderSide.none,
            ),
          ),
        ),
        const SizedBox(height: Dimens.gapSmall),
        Flexible(
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: clients.length,
            itemBuilder: (context, index) {
              final client = clients[index].client;
              return ListTile(
                contentPadding: EdgeInsets.zero,
                leading: InitialsAvatar(name: client.name, size: 40),
                title: Text(client.name, style: theme.textTheme.bodyLarge),
                onTap: () => Navigator.of(context).pop(client),
              );
            },
          ),
        ),
      ],
    );
  }
}
