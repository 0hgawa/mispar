import 'package:flutter/material.dart';
import 'package:mispar/src/core/theme/app_colors.dart';

/// A unica cor do app.
///
/// A referencia usa um acento so, e com parcimonia. Aqui ele marca o que custa
/// dinheiro — falta e horario sem resposta. Nada mais.
@immutable
class StatusColors extends ThemeExtension<StatusColors> {
  const new({required this.alert});

  static const light = StatusColors(alert: AppColors.accentDeep);
  static const dark = StatusColors(alert: AppColors.accent);

  final Color alert;

  @override
  StatusColors copyWith({Color? alert}) =>
      StatusColors(alert: alert ?? this.alert);

  @override
  StatusColors lerp(StatusColors? other, double t) => other == null
      ? this
      : StatusColors(alert: Color.lerp(alert, other.alert, t)!);
}

extension StatusColorsX on ThemeData {
  StatusColors get status => extension<StatusColors>()!;
}
