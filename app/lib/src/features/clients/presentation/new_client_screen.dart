import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:marcos_barber/src/core/theme/app_colors.dart';
import 'package:marcos_barber/src/features/clients/data/client_repository.dart';
import 'package:marcos_barber/src/features/clients/domain/client.dart';
import 'package:marcos_barber/src/shared/widgets/app_snack.dart';
import 'package:marcos_barber/src/shared/widgets/bottom_action.dart';
import 'package:marcos_barber/src/shared/widgets/confirm.dart';
import 'package:marcos_barber/src/shared/widgets/screen_title.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:uuid/uuid.dart';

/// Cadastrar cliente na mao — para quem chega sem nunca ter marcado.
///
/// Mesma forma da tela de marcar: cabecalho, secoes rotuladas e o botao
/// travado embaixo. Uma tarefa, uma tela.
class NewClientScreen extends ConsumerStatefulWidget {
  const new({super.key});

  @override
  ConsumerState<NewClientScreen> createState() => _NewClientScreenState();
}

class _NewClientScreenState extends ConsumerState<NewClientScreen> {
  final _name = TextEditingController();
  final _phone = TextEditingController();
  final _note = TextEditingController();
  bool _saving = false;

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    _note.dispose();
    super.dispose();
  }

  bool get _isValid => _name.text.trim().length >= 2;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Symbols.close_rounded, weight: 500),
          tooltip: 'Fechar',
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.only(bottom: Dimens.gapLarge),
        children: [
          const ScreenTitle(title: 'Novo cliente'),
          const SectionLabel('Quem'),
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: Dimens.screenGutter,
            ),
            child: Column(
              children: [
                _Field(
                  controller: _name,
                  hint: 'Nome',
                  icon: Symbols.person_rounded,
                  autofocus: true,
                  capitalize: true,
                  onChanged: (_) => setState(() {}),
                ),
                const SizedBox(height: Dimens.gapSmall),
                _Field(
                  controller: _phone,
                  hint: 'Telefone',
                  icon: Symbols.call_rounded,
                  keyboardType: TextInputType.phone,
                ),
              ],
            ),
          ),
          const SectionLabel('Do jeito que ele gosta'),
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: Dimens.screenGutter,
            ),
            child: _Field(
              controller: _note,
              hint: 'Máquina 2 nas laterais, tesoura em cima…',
              icon: Symbols.content_cut_rounded,
              capitalize: true,
              maxLines: 4,
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(
              Dimens.screenGutter,
              Dimens.gapSmall,
              Dimens.screenGutter,
              0,
            ),
            child: Text(
              'Só o nome é obrigatório. O resto dá para completar depois, na '
              'ficha dele.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
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
              : const Text('Cadastrar'),
        ),
      ),
    );
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    final name = _name.text.trim();
    final phone = _phone.text.trim();

    try {
      final repository = ref.read(clientRepositoryProvider);
      final existing = await repository.findExisting(name: name, phone: phone);

      // Numero e identidade: dois donos do mesmo telefone nao existem, e
      // cadastrar de novo partiria o historico dele em dois.
      final samePhone = existing.samePhone;
      if (samePhone != null) {
        if (!mounted) return;
        setState(() => _saving = false);
        showSnack(context, 'Esse telefone já é de ${samePhone.name}.');
        return;
      }

      // Nome igual so avisa: dois "Joao Silva" existem de verdade, e barrar
      // impediria um cadastro legitimo.
      final sameName = existing.sameName;
      if (sameName != null) {
        if (!mounted) return;
        final goOn = await _confirmSameName(sameName);
        if (!goOn) {
          if (mounted) setState(() => _saving = false);
          return;
        }
      }

      final id = const Uuid().v4();
      await repository.create(id: id, name: name, phone: phone);

      final note = _note.text.trim();
      if (note.isNotEmpty) await repository.saveNote(id, note);

      if (!mounted) return;
      Navigator.of(context).pop();
    } on Object {
      if (!mounted) return;
      setState(() => _saving = false);
      showSnack(context, 'Não consegui cadastrar. Tente de novo.');
    }
  }

  /// Pergunta antes de criar um segundo cadastro com o mesmo nome.
  Future<bool> _confirmSameName(Client existing) {
    return askToConfirm(
      context,
      title: 'Já existe esse nome',
      message: existing.phone.isEmpty
          ? '${existing.name} já está cadastrado. É a mesma pessoa?'
          : '${existing.name} já está cadastrado, no ${existing.phone}. '
                'É a mesma pessoa?',
      cancelLabel: 'É a mesma',
      confirmLabel: 'É outra pessoa',
      // Cadastrar outra pessoa nao apaga nada: botao sem cor de alerta.
      isDestructive: false,
    );
  }
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
    this.maxLines = 1,
  });

  final TextEditingController controller;
  final String hint;
  final IconData icon;
  final TextInputType? keyboardType;
  final ValueChanged<String>? onChanged;
  final bool autofocus;
  final bool capitalize;
  final int maxLines;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final isBox = maxLines > 1;

    return TextField(
      controller: controller,
      onChanged: onChanged,
      keyboardType: keyboardType,
      autofocus: autofocus,
      maxLines: maxLines,
      minLines: isBox ? maxLines : null,
      textCapitalization: capitalize
          ? TextCapitalization.words
          : TextCapitalization.none,
      style: theme.textTheme.bodyMedium,
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: theme.textTheme.bodyMedium?.copyWith(
          color: colors.onSurfaceVariant,
        ),
        prefixIcon: isBox
            ? null
            : Icon(icon, weight: 500, color: colors.onSurfaceVariant),
        filled: true,
        fillColor: colors.secondaryContainer,
        contentPadding: EdgeInsets.symmetric(
          horizontal: isBox ? Dimens.cardPadding : 0,
          vertical: isBox ? Dimens.cardPadding : 14,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(
            isBox ? Dimens.cardRadius : Dimens.pillRadius,
          ),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }
}
