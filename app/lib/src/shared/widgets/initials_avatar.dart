import 'package:flutter/material.dart';

/// Iniciais no lugar de foto.
///
/// A barbearia nao tem retrato de ninguem, e um circulo vazio seria pior que
/// nada. Duas letras quando ha sobrenome, uma quando nao ha — e o que faz uma
/// linha da lista nao parecer com a de cima.
class InitialsAvatar extends StatelessWidget {
  const new({
    required this.name,
    this.size = 42,
    this.faded = false,
    super.key,
  });

  final String name;
  final double size;

  /// Apagado: usado para quem ja esta na lista e nao entra de novo.
  final bool faded;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final parts = name.trim().split(RegExp(r'\s+'));
    final initials = switch (parts) {
      [] => '?',
      [final only] when only.isEmpty => '?',
      [final only] => only[0].toUpperCase(),
      [final first, ..., final last] => '${first[0]}${last[0]}'.toUpperCase(),
    };

    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: colors.secondaryContainer,
        shape: BoxShape.circle,
      ),
      child: Text(
        initials,
        style: theme.textTheme.labelLarge?.copyWith(
          color: faded ? colors.outline : colors.onSurfaceVariant,
        ),
      ),
    );
  }
}
