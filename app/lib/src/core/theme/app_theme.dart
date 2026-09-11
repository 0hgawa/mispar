import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:marcos_barber/src/core/theme/app_colors.dart';
import 'package:marcos_barber/src/core/theme/status_colors.dart';

/// Tema medido do app de referencia (Biblia YouVersion): fundo off-white
/// quente, card branco, **sem sombra** — a separacao e por tom e por espaco.
abstract final class AppTheme {
  /// Uma familia so. O que separa um nivel do outro e peso e tamanho.
  static const _font = 'Sans';

  static ThemeData get light => _build(Brightness.light);
  static ThemeData get dark => _build(Brightness.dark);

  static ThemeData _build(Brightness brightness) {
    final isLight = brightness == Brightness.light;

    final ground = isLight ? AppColors.lightGround : AppColors.darkGround;
    final card = isLight ? AppColors.lightCard : AppColors.darkCard;
    final fill = isLight ? AppColors.lightFill : AppColors.darkFill;
    final ink = isLight ? AppColors.lightInk : AppColors.darkInk;
    final inkSoft = isLight ? AppColors.lightInkSoft : AppColors.darkInkSoft;
    final edge = isLight ? AppColors.lightEdge : AppColors.darkEdge;
    final alert = isLight ? AppColors.accentDeep : AppColors.accent;

    final scheme = ColorScheme(
      brightness: brightness,
      primary: ink,
      onPrimary: card,
      secondary: inkSoft,
      onSecondary: card,
      // `secondaryContainer` e o preenchimento das pilulas paradas.
      secondaryContainer: fill,
      onSecondaryContainer: ink,
      surface: ground,
      onSurface: ink,
      surfaceContainerLowest: ground,
      surfaceContainerLow: card,
      surfaceContainer: card,
      surfaceContainerHigh: fill,
      surfaceContainerHighest: fill,
      onSurfaceVariant: inkSoft,
      outline: edge,
      outlineVariant: edge,
      error: alert,
      onError: card,
    );

    final base = ThemeData(colorScheme: scheme, fontFamily: _font);

    return base.copyWith(
      scaffoldBackgroundColor: ground,
      splashFactory: InkSparkle.splashFactory,
      extensions: [if (isLight) StatusColors.light else StatusColors.dark],
      textTheme: _textTheme(base.textTheme, ink, inkSoft),

      appBarTheme: AppBarTheme(
        backgroundColor: ground,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        systemOverlayStyle: isLight
            ? SystemUiOverlayStyle.dark
            : SystemUiOverlayStyle.light,
      ),

      // Card sem relevo: separa do fundo pelo tom e pelo espaco em volta.
      cardTheme: CardThemeData(
        color: card,
        elevation: 0,
        margin: EdgeInsets.zero,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(Dimens.cardRadius),
        ),
      ),

      // Barra sem pilula atras do icone: a aba ativa se marca pelo glifo cheio
      // e pelo rotulo em negrito, como na referencia.
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: ground,
        surfaceTintColor: Colors.transparent,
        indicatorColor: Colors.transparent,
        elevation: 0,
        height: 72,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        labelTextStyle: WidgetStateProperty.resolveWith(
          (states) => TextStyle(
            fontFamily: _font,
            fontSize: 12,
            height: 1.2,
            fontWeight: states.contains(WidgetState.selected)
                ? FontWeight.w700
                : FontWeight.w500,
            color: states.contains(WidgetState.selected) ? ink : inkSoft,
          ),
        ),
        iconTheme: WidgetStateProperty.resolveWith(
          (states) => IconThemeData(
            size: 26,
            color: states.contains(WidgetState.selected) ? ink : inkSoft,
          ),
        ),
      ),

      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: ink,
          foregroundColor: card,
          minimumSize: const Size.fromHeight(Dimens.buttonHeight),
          elevation: 0,
          textStyle: const TextStyle(
            fontFamily: _font,
            fontSize: 16,
            fontWeight: FontWeight.w700,
          ),
          shape: const StadiumBorder(),
        ),
      ),

      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: ink,
          minimumSize: const Size.fromHeight(Dimens.buttonHeight),
          side: BorderSide(color: edge),
          textStyle: const TextStyle(
            fontFamily: _font,
            fontSize: 16,
            fontWeight: FontWeight.w700,
          ),
          shape: const StadiumBorder(),
        ),
      ),

      // Pilula parada com preenchimento cinza, sem contorno; ativa em preto.
      chipTheme: ChipThemeData(
        backgroundColor: fill,
        selectedColor: ink,
        side: BorderSide.none,
        shape: const StadiumBorder(),
        showCheckmark: false,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        labelStyle: TextStyle(
          fontFamily: _font,
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: ink,
        ),
        secondaryLabelStyle: TextStyle(
          fontFamily: _font,
          fontSize: 14,
          fontWeight: FontWeight.w700,
          color: card,
        ),
      ),

      // Botao redondo preto, como o da referencia.
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: ink,
        foregroundColor: card,
        elevation: 2,
        focusElevation: 2,
        hoverElevation: 2,
        highlightElevation: 2,
        shape: const CircleBorder(),
      ),

      // Canto mais redondo e borda fina: o quadrado duro do Material brigava
      // com o resto, que e todo arredondado.
      checkboxTheme: CheckboxThemeData(
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(6)),
        ),
        // Nem o traco duro do Material, nem a borda de divisoria, que some no
        // fundo claro: um meio-termo que ainda da para achar com o olho.
        side: BorderSide(color: inkSoft.withValues(alpha: 0.4), width: 1.5),
      ),

      dividerTheme: DividerThemeData(color: edge, space: 1, thickness: 1),

      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: card,
        surfaceTintColor: Colors.transparent,
        showDragHandle: true,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
      ),

      snackBarTheme: SnackBarThemeData(
        backgroundColor: ink,
        contentTextStyle: TextStyle(fontFamily: _font, color: card),
        behavior: SnackBarBehavior.floating,
        shape: const StadiumBorder(),
      ),
    );
  }

  static TextTheme _textTheme(TextTheme base, Color ink, Color soft) {
    return base
        .copyWith(
          // O numero grande de dinheiro: o unico lugar que passa de 24.
          displaySmall: const TextStyle(
            fontSize: 40,
            fontWeight: FontWeight.w800,
            letterSpacing: -1.2,
            height: 1.1,
          ),
          // Titulo da tela.
          headlineMedium: const TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.4,
            height: 1.15,
          ),
          // Nome do cliente: o conteudo do card.
          headlineSmall: const TextStyle(
            fontSize: 19,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.3,
            height: 1.2,
          ),
          titleMedium: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w500,
            color: soft,
            height: 1.3,
          ),
          // Rotulo de secao.
          titleSmall: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.2,
          ),
          bodyLarge: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            height: 1.35,
          ),
          bodyMedium: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w500,
            height: 1.35,
          ),
          bodySmall: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            height: 1.3,
          ),
          labelLarge: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w700,
          ),
          labelMedium: const TextStyle(
            fontSize: 12.5,
            fontWeight: FontWeight.w600,
          ),
        )
        .apply(bodyColor: ink, displayColor: ink);
  }
}
