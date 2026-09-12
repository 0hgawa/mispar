import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:mispar/src/shared/widgets/empty_state.dart';

/// Desenha os tres estados de um [AsyncValue] no mesmo lugar, para nenhuma
/// tela precisar repetir loading e erro.
class AsyncView<T> extends StatelessWidget {
  const new({
    required this.value,
    required this.onRetry,
    required this.builder,
    super.key,
  });

  final AsyncValue<T> value;
  final VoidCallback onRetry;
  final Widget Function(T data) builder;

  @override
  Widget build(BuildContext context) {
    return value.when(
      // Recarregar em silencio: o Drift reemite a cada escrita e piscar um
      // spinner a cada mudanca seria pior que nao mostrar nada.
      skipLoadingOnReload: true,
      data: builder,
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => EmptyState(
        icon: Symbols.error_rounded,
        title: 'Não consegui carregar',
        message: 'Algo falhou ao ler a agenda. Tente de novo.',
        action: FilledButton(
          onPressed: onRetry,
          child: const Text('Tentar de novo'),
        ),
      ),
    );
  }
}
