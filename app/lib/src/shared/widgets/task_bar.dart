import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

/// Cabeçalho de uma tarefa: fechar e o nome dela, na mesma linha.
///
/// O título ficava embaixo do `X`, ocupando uma faixa inteira só para uma
/// palavra e empurrando o primeiro campo para o meio da tela — onde o teclado
/// alcança. Ao lado do botão, a mesma palavra não custa altura nenhuma.
///
/// Mora aqui, e não copiado em cada formulário, porque **é a regra do `X`**:
/// quem tem esta barra cobre o app inteiro, e quem tem seta de voltar fica
/// dentro da aba — a regra inteira esta em task_route.dart.
class TaskBar extends StatelessWidget implements PreferredSizeWidget {
  const new({required this.title, this.actions, super.key});

  final String title;

  /// Botão do canto direito, quando a tarefa tem um — "Todos", "Nenhum".
  final List<Widget>? actions;

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    return AppBar(
      leading: IconButton(
        icon: const Icon(Symbols.close_rounded, weight: 500),
        tooltip: 'Fechar',
        onPressed: () => Navigator.of(context).pop(),
      ),
      // Colado no botao: com o espacamento do Material, o titulo flutuaria
      // longe do X e pareceria pertencer a outra coisa.
      titleSpacing: 0,
      title: Text(
        title,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: Theme.of(context).textTheme.headlineMedium,
      ),
      actions: actions,
    );
  }
}
