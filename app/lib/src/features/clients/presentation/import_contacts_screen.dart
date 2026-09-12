import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:mispar/src/core/theme/app_colors.dart';
import 'package:mispar/src/features/clients/data/client_repository.dart';
import 'package:mispar/src/features/clients/data/phone_contacts.dart';
import 'package:mispar/src/shared/formatters/text.dart';
import 'package:mispar/src/shared/task_route.dart';
import 'package:mispar/src/shared/widgets/app_snack.dart';
import 'package:mispar/src/shared/widgets/bottom_action.dart';
import 'package:mispar/src/shared/widgets/empty_state.dart';
import 'package:mispar/src/shared/widgets/initials_avatar.dart';
import 'package:mispar/src/shared/widgets/screen_title.dart';
import 'package:mispar/src/shared/widgets/task_bar.dart';
import 'package:uuid/uuid.dart';

/// Traz a agenda do celular para dentro do app.
///
/// É o caminho que faz a lista de clientes deixar de nascer vazia — e, junto,
/// o que dá ao robô do WhatsApp o telefone de todo mundo. Digitar duzentos
/// clientes à mão não acontece.
///
/// Quem já está cadastrado aparece marcado e travado: importar de novo criaria
/// o mesmo cliente duas vezes e partiria o histórico dele em dois.
class ImportContactsScreen extends ConsumerStatefulWidget {
  const new({super.key});

  static Future<void> show(BuildContext context) {
    return openTask(context, (_) => const ImportContactsScreen());
  }

  @override
  ConsumerState<ImportContactsScreen> createState() =>
      _ImportContactsScreenState();
}

class _ImportContactsScreenState extends ConsumerState<ImportContactsScreen> {
  final _search = TextEditingController();

  List<PhoneContact>? _contacts;
  ContactsDenied? _denied;

  /// Os telefones que ja viraram cliente. Lido uma vez, na abertura.
  Set<String> _known = const {};

  /// As chaves marcadas para importar.
  final _chosen = <String>{};

  String _term = '';
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final known = await ref.read(clientRepositoryProvider).phoneKeys();
    final result = await readPhoneContacts();
    if (!mounted) return;

    setState(() {
      _known = known;
      _contacts = result.contacts;
      _denied = result.denied;
      // Quem ainda nao e cliente ja vem marcado: o caso comum e trazer todo
      // mundo, e desmarcar um ou outro e mais rapido que marcar duzentos.
      _chosen
        ..clear()
        ..addAll([
          for (final contact in result.contacts)
            if (!known.contains(contact.key)) contact.key,
        ]);
    });
  }

  /// A lista filtrada pela busca. Roda sobre o que ja esta na memoria.
  List<PhoneContact> get _shown {
    final all = _contacts ?? const <PhoneContact>[];
    final term = normalizeForSearch(_term.trim());
    if (term.isEmpty) return all;

    return [
      for (final contact in all)
        if (normalizeForSearch(contact.name).contains(term) ||
            contact.key.contains(term))
          contact,
    ];
  }

  @override
  Widget build(BuildContext context) {
    final contacts = _contacts;

    return Scaffold(
      appBar: TaskBar(
        title: 'Da agenda',
        actions: [
          if (contacts != null && contacts.isNotEmpty)
            TextButton(
              onPressed: _toggleAll,
              child: Text(_allChosen ? 'Nenhum' : 'Todos'),
            ),
        ],
      ),
      body: switch ((contacts, _denied)) {
        (null, _) => const Center(child: CircularProgressIndicator()),
        (_, ContactsDenied.refused) => const EmptyState(
          icon: Symbols.download_rounded,
          title: 'Sem acesso à agenda',
          message:
              'O app precisa ler os contatos do celular para trazer seus '
              'clientes. Você pode liberar nos ajustes do Android.',
        ),
        (_, ContactsDenied.empty) => const EmptyState(
          icon: Symbols.download_rounded,
          title: 'Nenhum contato com telefone',
          message: 'A agenda do celular não tem ninguém com número salvo.',
        ),
        _ => _list(contacts!),
      },
      bottomNavigationBar: contacts == null || _denied != null
          ? null
          : BottomAction(
              child: FilledButton(
                onPressed: _chosen.isEmpty || _saving ? null : _import,
                child: _saving
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(
                        _chosen.length == 1
                            ? 'Trazer 1 cliente'
                            : 'Trazer ${_chosen.length} clientes',
                      ),
              ),
            ),
    );
  }

  bool get _allChosen {
    final free = [
      for (final contact in _contacts ?? const <PhoneContact>[])
        if (!_known.contains(contact.key)) contact.key,
    ];
    return free.isNotEmpty && _chosen.length == free.length;
  }

  void _toggleAll() {
    final free = [
      for (final contact in _contacts ?? const <PhoneContact>[])
        if (!_known.contains(contact.key)) contact.key,
    ];

    setState(() {
      final wasAll = _allChosen;
      _chosen.clear();
      if (!wasAll) _chosen.addAll(free);
    });
  }

  Widget _list(List<PhoneContact> contacts) {
    final shown = _shown;
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionLabel(
          contacts.length == 1 ? '1 contato' : '${contacts.length} contatos',
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(
            Dimens.screenGutter,
            0,
            Dimens.screenGutter,
            Dimens.gapMedium,
          ),
          child: TextField(
            controller: _search,
            onChanged: (value) => setState(() => _term = value),
            style: theme.textTheme.bodyMedium,
            decoration: InputDecoration(
              hintText: 'Buscar na agenda',
              hintStyle: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
              prefixIcon: Icon(
                Symbols.search_rounded,
                weight: 500,
                color: theme.colorScheme.onSurfaceVariant,
              ),
              filled: true,
              fillColor: theme.colorScheme.secondaryContainer,
              contentPadding: const EdgeInsets.symmetric(vertical: 14),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(Dimens.pillRadius),
                borderSide: BorderSide.none,
              ),
            ),
          ),
        ),
        Expanded(
          // Construtor, e nao lista pronta: uma agenda de mil contatos so
          // monta as linhas que estao na tela.
          child: ListView.builder(
            itemCount: shown.length,
            itemBuilder: (context, index) {
              final contact = shown[index];
              final already = _known.contains(contact.key);

              return _ContactRow(
                contact: contact,
                already: already,
                chosen: _chosen.contains(contact.key),
                onToggle: already
                    ? null
                    : () => setState(() {
                        if (!_chosen.remove(contact.key)) {
                          _chosen.add(contact.key);
                        }
                      }),
              );
            },
          ),
        ),
      ],
    );
  }

  Future<void> _import() async {
    setState(() => _saving = true);
    const uuid = Uuid();

    final people = [
      for (final contact in _contacts ?? const <PhoneContact>[])
        if (_chosen.contains(contact.key))
          (id: uuid.v4(), name: contact.name, phone: contact.phone),
    ];

    try {
      await ref.read(clientRepositoryProvider).importAll(people);
      if (!mounted) return;
      Navigator.of(context).pop();
      showSnack(
        context,
        people.length == 1
            ? '1 cliente trazido da agenda.'
            : '${people.length} clientes trazidos da agenda.',
      );
    } on Object {
      if (!mounted) return;
      setState(() => _saving = false);
      showSnack(context, 'Não consegui trazer. Tente de novo.');
    }
  }
}

class _ContactRow extends StatelessWidget {
  const new({
    required this.contact,
    required this.already,
    required this.chosen,
    required this.onToggle,
  });

  final PhoneContact contact;

  /// Já é cliente. Fica marcado e travado.
  final bool already;
  final bool chosen;
  final VoidCallback? onToggle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(
        horizontal: Dimens.screenGutter,
      ),
      onTap: onToggle,
      leading: InitialsAvatar(name: contact.name, size: 40, faded: already),
      title: Text(
        contact.name,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: theme.textTheme.bodyLarge?.copyWith(
          color: already ? colors.onSurfaceVariant : colors.onSurface,
        ),
      ),
      subtitle: Text(
        already ? 'já é cliente' : contact.phone,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: theme.textTheme.bodySmall?.copyWith(
          color: colors.onSurfaceVariant,
        ),
      ),
      trailing: Checkbox(
        value: already || chosen,
        onChanged: onToggle == null ? null : (_) => onToggle!(),
      ),
    );
  }
}
