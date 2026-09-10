import 'package:flutter/material.dart';

/// Paleta medida pixel a pixel do app de referencia (Biblia YouVersion).
///
/// Tres decisoes vieram de la e mudam o app inteiro:
/// 1. O fundo e off-white **quente**, nao cinza frio.
/// 2. A tinta nao e preto puro, e o cinza secundario e escuro o bastante para
///    ser lido de relance — nao um cinza decorativo.
/// 3. Existe **uma** cor de acento, e ela so aparece onde ha problema.
abstract final class AppColors {
  // ------------------------------------------------------------------ claro
  static const lightGround = Color(0xFFF8F7F7);
  static const lightCard = Color(0xFFFFFFFF);

  /// Preenchimento de pilula e celula que nao esta ativa.
  static const lightFill = Color(0xFFEDEBEB);
  static const lightInk = Color(0xFF121212);
  static const lightInkSoft = Color(0xFF636161);
  static const lightEdge = Color(0xFFE0DDDD);

  // ------------------------------------------------------------------ escuro
  static const darkGround = Color(0xFF0E0E0E);
  static const darkCard = Color(0xFF1A1919);
  static const darkFill = Color(0xFF262424);
  static const darkInk = Color(0xFFF5F3F3);
  static const darkInkSoft = Color(0xFFA6A2A2);
  static const darkEdge = Color(0xFF2E2C2C);

  /// O unico acento do app. So aparece onde ha problema: falta e horario sem
  /// resposta. Nunca como enfeite.
  static const accent = Color(0xFFFF3D4D);
  static const accentDeep = Color(0xFFD32234);
}

/// Medidas tiradas do app de referencia, em pixels no aparelho (440 dpi,
/// densidade 2.75) e convertidas para dp.
abstract final class Dimens {
  /// 66 px medidos. Bem mais generoso que a media — e o que da o ar de calma.
  static const screenGutter = 24.0;

  static const cardPadding = 18.0;

  /// 29 px medidos no canto.
  static const cardRadius = 11.0;

  static const cardGap = 10.0;

  static const pillRadius = 999.0;

  /// 40dp no original; subimos para 52 porque abaixo de 48 o dedo erra.
  static const buttonHeight = 52.0;

  static const gapSmall = 8.0;
  static const gapMedium = 16.0;
  static const gapLarge = 24.0;
}
