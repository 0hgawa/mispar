import 'package:flutter/material.dart';
import 'package:mispar/src/shared/widgets/app_card.dart';
import 'package:mispar/src/shared/widgets/initials_avatar.dart';

/// A linha de um cliente: retrato, nome, uma linha de detalhe, e o que vier
/// à direita.
///
/// Duas listas mostram cliente — a aba de Clientes e a de quem sumiu. Elas
/// diferem só no que fica à direita e no que a segunda linha diz; o resto tem
/// que ser idêntico, e uma classe só é o que garante que continue sendo.
class ClientRow extends StatelessWidget {
  const new({
    required this.name,
    required this.detail,
    required this.onTap,
    this.trailing,
    this.detailLines = 2,
    super.key,
  });

  final String name;
  final String detail;

  /// O que fica à direita, quando há. Na aba de Clientes não há: nome e
  /// anotação bastam, e o resto é ruído numa lista que se lê de cima a baixo.
  final Widget? trailing;
  final VoidCallback onTap;

  /// Anotação de cliente pode ter duas linhas; um detalhe de uma linha só
  /// ficaria com o card alto à toa.
  final int detailLines;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AppCard(
      onTap: onTap,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InitialsAvatar(name: name),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.headlineSmall,
                ),
                const SizedBox(height: 3),
                Text(
                  detail,
                  maxLines: detailLines,
                  overflow: TextOverflow.ellipsis,
                  // `bodySmall`, que é o posto do metadado — e não
                  // `bodyMedium`, que é texto corrente. Com 15 embaixo de 19 a
                  // segunda linha quase empatava com o nome; com 13 ela vira
                  // apoio, e o nome volta a mandar no cartão.
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          if (trailing != null) ...[const SizedBox(width: 10), trailing!],
        ],
      ),
    );
  }
}
