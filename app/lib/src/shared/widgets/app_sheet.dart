import 'package:flutter/material.dart';
import 'package:mispar/src/core/theme/app_colors.dart';

/// A folha de baixo do app.
///
/// Um lugar so para o formato: alca de arrastar, recuo, area segura e rolagem.
/// Antes cada folha montava o proprio esqueleto, e elas iam ficando diferentes
/// entre si sem ninguem decidir isso.
///
/// Sempre `isScrollControlled`: sem isso a folha para em metade da tela e o
/// conteudo estoura por alguns pixels — foi o que aconteceu com a lista de
/// periodos, que so cabia com fonte pequena.
///
/// O [builder] recebe o contexto **da folha**: e com ele que se fecha
/// (`Navigator.of(sheetContext).pop(valor)`), nao com o da tela de tras.
Future<T?> showAppSheet<T>(
  BuildContext context, {
  required WidgetBuilder builder,
  String? title,
}) {
  return showModalBottomSheet<T>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    // Sobe pela raiz para cobrir a barra de abas junto com o resto. Folha que
    // para em cima da barra deixa o app parecer que continua navegável por
    // baixo dela, e não continua: o que está aberto é modal.
    useRootNavigator: true,
    builder: (sheetContext) {
      final theme = Theme.of(sheetContext);

      return SafeArea(
        child: ConstrainedBox(
          // Folha nao pode virar tela: acima disto o certo e uma rota.
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(sheetContext).height * 0.75,
          ),
          child: SingleChildScrollView(
            // Sobe junto com o teclado quando a folha tem campo de texto.
            padding: EdgeInsets.only(
              bottom: MediaQuery.viewInsetsOf(sheetContext).bottom,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (title != null)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(
                      Dimens.screenGutter,
                      0,
                      Dimens.screenGutter,
                      Dimens.gapMedium,
                    ),
                    child: Text(title, style: theme.textTheme.headlineSmall),
                  ),
                builder(sheetContext),
                const SizedBox(height: Dimens.gapMedium),
              ],
            ),
          ),
        ),
      );
    },
  );
}

/// Escolher um item de uma lista curta.
///
/// O que esta valendo agora vem marcado: sem isso o Marcos abre a folha e nao
/// sabe de onde esta saindo.
Future<T?> showOptionSheet<T>(
  BuildContext context, {
  required List<({T value, String label})> options,
  T? current,
  String? title,
}) {
  return showAppSheet<T>(
    context,
    title: title,
    builder: (sheetContext) => Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final option in options)
          ListTile(
            contentPadding: const EdgeInsets.symmetric(
              horizontal: Dimens.screenGutter,
            ),
            title: Text(option.label),
            trailing: option.value == current
                ? const Icon(Icons.check_rounded)
                : null,
            onTap: () => Navigator.of(sheetContext).pop(option.value),
          ),
      ],
    ),
  );
}
