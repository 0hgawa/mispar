import 'package:flutter/material.dart';

/// Quanto tempo a pilula fica na tela.
///
/// O padrao do Material e quatro segundos, pensado para aviso que traz um
/// botao de desfazer. Nenhum dos nossos traz: e so confirmacao curta, e
/// quatro segundos tapando o rodape e tempo demais para tres palavras.
const _showing = Duration(seconds: 2);

/// Folga de cada lado, dentro da pilula.
const _sidePadding = 18.0;

/// Folga total nas laterais da tela, para a pilula nunca encostar na borda.
const _screenRoom = 48.0;

/// Um aviso curto no rodape, do tamanho do texto.
///
/// O SnackBar do Material ocupa a largura inteira da tela para dizer duas
/// palavras, e tapa o que esta embaixo. Aqui a largura e medida a partir do
/// proprio texto, com a fonte de verdade: a pilula fica pouco maior que a
/// frase, e o resto da tela continua visivel.
///
/// **So chame para o que a tela nao mostra sozinha.** Cadastrou e voltou para
/// a lista? O item aparecendo la ja e a confirmacao — avisar de novo e repetir
/// o que os olhos ja viram e tapar o rodape a toa.
void showSnack(BuildContext context, String message) {
  final theme = Theme.of(context);
  final style =
      theme.snackBarTheme.contentTextStyle ?? theme.textTheme.bodyMedium!;
  final room = MediaQuery.sizeOf(context).width - _screenRoom;

  final painter = TextPainter(
    text: TextSpan(text: message, style: style),
    textDirection: Directionality.of(context),
    maxLines: 3,
  )..layout(maxWidth: room - _sidePadding * 2);

  // A maior linha desenhada — e nao o limite que foi dado ao layout.
  final lines = painter.computeLineMetrics();
  final text = lines.isEmpty
      ? painter.width
      : lines.map((line) => line.width).reduce((a, b) => a > b ? a : b);

  ScaffoldMessenger.of(context)
    ..clearSnackBars()
    ..showSnackBar(
      SnackBar(
        content: Text(message),
        duration: _showing,
        padding: const EdgeInsets.symmetric(
          horizontal: _sidePadding,
          vertical: 12,
        ),
        width: text + _sidePadding * 2,
      ),
    );
}
