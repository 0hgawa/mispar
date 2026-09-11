import 'dart:async';

import 'package:flutter/material.dart';
import 'package:marcos_barber/src/core/theme/app_colors.dart';
import 'package:marcos_barber/src/shared/widgets/app_card.dart';
import 'package:material_symbols_icons/symbols.dart';

/// A anotacao do cliente — o campo mais importante do app.
///
/// Fica em modo leitura por padrao e vira campo com um toque. Salvar acontece
/// ao sair do campo, sem botao: o Marcos escreve com uma mao e sai.
class NoteEditor extends StatefulWidget {
  const new({required this.note, required this.onSave, super.key});

  final String? note;
  final Future<void> Function(String? note) onSave;

  @override
  State<NoteEditor> createState() => _NoteEditorState();
}

class _NoteEditorState extends State<NoteEditor> {
  late final TextEditingController _controller = TextEditingController(
    text: widget.note ?? '',
  );
  final _focus = FocusNode();
  bool _editing = false;

  @override
  void initState() {
    super.initState();
    _focus.addListener(() {
      if (!_focus.hasFocus && _editing) unawaited(_finish());
    });
  }

  @override
  void didUpdateWidget(NoteEditor oldWidget) {
    super.didUpdateWidget(oldWidget);
    // A nota pode mudar pela sincronia enquanto a tela esta aberta. So aceita
    // o valor de fora quando ninguem esta digitando.
    if (!_editing && widget.note != oldWidget.note) {
      _controller.text = widget.note ?? '';
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  Future<void> _finish() async {
    setState(() => _editing = false);
    await widget.onSave(_controller.text);
    if (!mounted) return;
  }

  void _start() {
    setState(() => _editing = true);
    _focus.requestFocus();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    if (_editing) {
      return AppCard(
        child: TextField(
          controller: _controller,
          focusNode: _focus,
          maxLines: null,
          minLines: 3,
          autofocus: true,
          textCapitalization: TextCapitalization.sentences,
          style: theme.textTheme.bodyMedium,
          decoration: InputDecoration(
            isDense: true,
            border: InputBorder.none,
            hintText: 'Máquina 2 nas laterais, tesoura em cima…',
            hintStyle: theme.textTheme.bodyMedium?.copyWith(
              color: colors.onSurfaceVariant,
            ),
          ),
          onTapOutside: (_) => _focus.unfocus(),
        ),
      );
    }

    final note = widget.note;
    final isEmpty = note == null || note.trim().isEmpty;

    return AppCard(
      onTap: _start,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Text(
              isEmpty
                  ? 'Toque para anotar o corte, o horário de sempre, o que ele não gosta.'
                  : note,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: isEmpty ? colors.onSurfaceVariant : colors.onSurface,
              ),
            ),
          ),
          const SizedBox(width: Dimens.gapMedium),
          Icon(
            Symbols.edit_rounded,
            weight: 500,
            size: 20,
            color: colors.onSurfaceVariant,
          ),
        ],
      ),
    );
  }
}
