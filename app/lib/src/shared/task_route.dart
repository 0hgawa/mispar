import 'package:flutter/material.dart';

/// Abre uma tarefa: tela que cobre o app inteiro, barra de baixo incluída.
///
/// A regra do app, num lugar só, para não ficar pela metade em cada tela:
///
/// - **`X` no canto** — é tarefa. Cobre tudo, porque trocar de aba no meio
///   dela não leva a lugar nenhum: marcar, cadastrar, lançar, importar.
/// - **Seta de voltar** — é navegação. Fica dentro da aba e a barra continua
///   visível: a lista de serviços, a ficha do cliente, os horários.
///
/// As telas que o `go_router` abre pelo `parentNavigatorKey` da raiz seguem a
/// mesma regra por outro caminho; esta função é para as que são empilhadas na
/// mão.
Future<void> openTask(BuildContext context, WidgetBuilder builder) {
  return Navigator.of(context, rootNavigator: true)
      .push(MaterialPageRoute<void>(builder: builder));
}
