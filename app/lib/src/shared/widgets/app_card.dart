import 'package:flutter/material.dart';
import 'package:mispar/src/core/theme/app_colors.dart';

/// O card do app: branco sobre o off-white, canto de 11 e **sem sombra**.
///
/// A referencia separa a superficie do fundo por tom e por espaco, nao por
/// relevo. Sombra aqui so voltaria a sujar a tela.
class AppCard extends StatefulWidget {
  const new({required this.child, this.onTap, super.key});

  final Widget child;
  final VoidCallback? onTap;

  @override
  State<AppCard> createState() => _AppCardState();
}

class _AppCardState extends State<AppCard> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(Dimens.cardRadius);
    final tappable = widget.onTap != null;

    return AnimatedScale(
      // Encolhe de leve no toque. Sem ripple espalhando.
      scale: _pressed ? 0.985 : 1,
      duration: const Duration(milliseconds: 110),
      curve: Curves.easeOut,
      child: Material(
        color: Theme.of(context).colorScheme.surfaceContainer,
        borderRadius: radius,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: widget.onTap,
          onHighlightChanged: tappable
              ? (value) => setState(() => _pressed = value)
              : null,
          splashFactory: NoSplash.splashFactory,
          highlightColor: Colors.transparent,
          child: Padding(
            padding: const EdgeInsets.all(Dimens.cardPadding),
            child: widget.child,
          ),
        ),
      ),
    );
  }
}
