import 'package:flutter/material.dart';
import '../BaseDatos/base_datos.dart';

class ThemeManager extends ChangeNotifier with WidgetsBindingObserver {
  static final ThemeManager instance = ThemeManager();

  ThemeMode _themeMode = ThemeMode.system;
  ThemeMode get themeMode => _themeMode;

  bool _isDark = false;
  bool get isDark => _isDark;
  bool get isDarkMode => _isDark;

  ThemeManager() {
    WidgetsBinding.instance.addObserver(this);
  }

  Future<void> inicializar() async {
    try {
      final db = await BaseDeDatos.instancia.database;
      final mapas = await db.query(
        'configuracion',
        where: 'id = ?',
        whereArgs: [1],
      );
      if (mapas.isNotEmpty) {
        final val = mapas.first['temaOscuro'];
        if (val == 0) {
          _themeMode = ThemeMode.light;
        } else if (val == 1) {
          _themeMode = ThemeMode.dark;
        } else {
          _themeMode = ThemeMode.system;
        }
      } else {
        _themeMode = ThemeMode.system;
      }
    } catch (_) {
      _themeMode = ThemeMode.system;
    }

    final systemIsDark =
        WidgetsBinding.instance.platformDispatcher.platformBrightness ==
            Brightness.dark;
    _updateIsDark(systemIsDark: systemIsDark);
  }

  @override
  void didChangePlatformBrightness() {
    if (_themeMode == ThemeMode.system) {
      final systemIsDark =
          WidgetsBinding.instance.platformDispatcher.platformBrightness ==
              Brightness.dark;
      if (_isDark != systemIsDark) {
        _isDark = systemIsDark;
        AppColors.isDark = _isDark;
        notifyListeners();
      }
    }
  }

  Future<void> setThemeMode(ThemeMode mode, {bool? systemIsDark}) async {
    _themeMode = mode;
    final sysDark = systemIsDark ??
        (WidgetsBinding.instance.platformDispatcher.platformBrightness ==
            Brightness.dark);
    _updateIsDark(systemIsDark: sysDark);
    notifyListeners();

    try {
      final db = await BaseDeDatos.instancia.database;
      int val = 2; // Automático (sistema)
      if (mode == ThemeMode.light) val = 0;
      if (mode == ThemeMode.dark) val = 1;
      await db.update(
        'configuracion',
        {'temaOscuro': val},
        where: 'id = ?',
        whereArgs: [1],
      );
    } catch (_) {}
  }

  void updateSystemBrightness(Brightness brightness) {
    if (_themeMode == ThemeMode.system) {
      final newIsDark = brightness == Brightness.dark;
      if (_isDark != newIsDark) {
        _isDark = newIsDark;
        AppColors.isDark = _isDark;
        notifyListeners();
      }
    }
  }

  void _updateIsDark({bool? systemIsDark}) {
    if (_themeMode == ThemeMode.dark) {
      _isDark = true;
    } else if (_themeMode == ThemeMode.light) {
      _isDark = false;
    } else {
      _isDark = systemIsDark ??
          (WidgetsBinding.instance.platformDispatcher.platformBrightness ==
              Brightness.dark);
    }
    AppColors.isDark = _isDark;
  }
}

/// Extensión de tema declarativa y reactiva nativa para Planteapp.
/// Permite inyectar y consumir la paleta botánica a través del árbol de widgets
/// mediante `Theme.of(context).extension<BotanicalThemeColors>()` o `context.botanicalColors`.
@immutable
class BotanicalThemeColors extends ThemeExtension<BotanicalThemeColors> {
  final Color primary;
  final Color onPrimary;
  final Color primaryContainer;
  final Color onPrimaryContainer;
  final Color secondary;
  final Color onSecondary;
  final Color secondaryContainer;
  final Color onSecondaryContainer;
  final Color tertiary;
  final Color onTertiary;
  final Color appBackground;
  final Color screenBackground;
  final Color card;
  final Color secondarySurface;
  final Color textPrimary;
  final Color textSecondary;
  final Color border;
  final Color error;
  final Color onError;
  final Color brightGreen;
  final Color amber;
  final Color coral;
  final Color turquoise;
  final Color subtleGreen;
  final Color subtleAmber;
  final Color subtleCoral;
  final Color subtleTurquoise;
  final Color homeCardBackground;
  final Color homeCardBorder;
  final LinearGradient darkCardGradient;
  final LinearGradient? homeCardGradient;

  const BotanicalThemeColors({
    required this.primary,
    required this.onPrimary,
    required this.primaryContainer,
    required this.onPrimaryContainer,
    required this.secondary,
    required this.onSecondary,
    required this.secondaryContainer,
    required this.onSecondaryContainer,
    required this.tertiary,
    required this.onTertiary,
    required this.appBackground,
    required this.screenBackground,
    required this.card,
    required this.secondarySurface,
    required this.textPrimary,
    required this.textSecondary,
    required this.border,
    required this.error,
    required this.onError,
    required this.brightGreen,
    required this.amber,
    required this.coral,
    required this.turquoise,
    required this.subtleGreen,
    required this.subtleAmber,
    required this.subtleCoral,
    required this.subtleTurquoise,
    required this.homeCardBackground,
    required this.homeCardBorder,
    required this.darkCardGradient,
    this.homeCardGradient,
  });

  // Accesores semánticos adicionales
  Color get surface => screenBackground;
  Color get warning => secondary;
  Color get onWarning => onSecondary;

  @override
  BotanicalThemeColors copyWith({
    Color? primary,
    Color? onPrimary,
    Color? primaryContainer,
    Color? onPrimaryContainer,
    Color? secondary,
    Color? onSecondary,
    Color? secondaryContainer,
    Color? onSecondaryContainer,
    Color? tertiary,
    Color? onTertiary,
    Color? appBackground,
    Color? screenBackground,
    Color? card,
    Color? secondarySurface,
    Color? textPrimary,
    Color? textSecondary,
    Color? border,
    Color? error,
    Color? onError,
    Color? brightGreen,
    Color? amber,
    Color? coral,
    Color? turquoise,
    Color? subtleGreen,
    Color? subtleAmber,
    Color? subtleCoral,
    Color? subtleTurquoise,
    Color? homeCardBackground,
    Color? homeCardBorder,
    LinearGradient? darkCardGradient,
    LinearGradient? homeCardGradient,
  }) {
    return BotanicalThemeColors(
      primary: primary ?? this.primary,
      onPrimary: onPrimary ?? this.onPrimary,
      primaryContainer: primaryContainer ?? this.primaryContainer,
      onPrimaryContainer: onPrimaryContainer ?? this.onPrimaryContainer,
      secondary: secondary ?? this.secondary,
      onSecondary: onSecondary ?? this.onSecondary,
      secondaryContainer: secondaryContainer ?? this.secondaryContainer,
      onSecondaryContainer: onSecondaryContainer ?? this.onSecondaryContainer,
      tertiary: tertiary ?? this.tertiary,
      onTertiary: onTertiary ?? this.onTertiary,
      appBackground: appBackground ?? this.appBackground,
      screenBackground: screenBackground ?? this.screenBackground,
      card: card ?? this.card,
      secondarySurface: secondarySurface ?? this.secondarySurface,
      textPrimary: textPrimary ?? this.textPrimary,
      textSecondary: textSecondary ?? this.textSecondary,
      border: border ?? this.border,
      error: error ?? this.error,
      onError: onError ?? this.onError,
      brightGreen: brightGreen ?? this.brightGreen,
      amber: amber ?? this.amber,
      coral: coral ?? this.coral,
      turquoise: turquoise ?? this.turquoise,
      subtleGreen: subtleGreen ?? this.subtleGreen,
      subtleAmber: subtleAmber ?? this.subtleAmber,
      subtleCoral: subtleCoral ?? this.subtleCoral,
      subtleTurquoise: subtleTurquoise ?? this.subtleTurquoise,
      homeCardBackground: homeCardBackground ?? this.homeCardBackground,
      homeCardBorder: homeCardBorder ?? this.homeCardBorder,
      darkCardGradient: darkCardGradient ?? this.darkCardGradient,
      homeCardGradient: homeCardGradient ?? this.homeCardGradient,
    );
  }

  @override
  BotanicalThemeColors lerp(ThemeExtension<BotanicalThemeColors>? other, double t) {
    if (other is! BotanicalThemeColors) {
      return this;
    }
    return BotanicalThemeColors(
      primary: Color.lerp(primary, other.primary, t)!,
      onPrimary: Color.lerp(onPrimary, other.onPrimary, t)!,
      primaryContainer: Color.lerp(primaryContainer, other.primaryContainer, t)!,
      onPrimaryContainer: Color.lerp(onPrimaryContainer, other.onPrimaryContainer, t)!,
      secondary: Color.lerp(secondary, other.secondary, t)!,
      onSecondary: Color.lerp(onSecondary, other.onSecondary, t)!,
      secondaryContainer: Color.lerp(secondaryContainer, other.secondaryContainer, t)!,
      onSecondaryContainer: Color.lerp(onSecondaryContainer, other.onSecondaryContainer, t)!,
      tertiary: Color.lerp(tertiary, other.tertiary, t)!,
      onTertiary: Color.lerp(onTertiary, other.onTertiary, t)!,
      appBackground: Color.lerp(appBackground, other.appBackground, t)!,
      screenBackground: Color.lerp(screenBackground, other.screenBackground, t)!,
      card: Color.lerp(card, other.card, t)!,
      secondarySurface: Color.lerp(secondarySurface, other.secondarySurface, t)!,
      textPrimary: Color.lerp(textPrimary, other.textPrimary, t)!,
      textSecondary: Color.lerp(textSecondary, other.textSecondary, t)!,
      border: Color.lerp(border, other.border, t)!,
      error: Color.lerp(error, other.error, t)!,
      onError: Color.lerp(onError, other.onError, t)!,
      brightGreen: Color.lerp(brightGreen, other.brightGreen, t)!,
      amber: Color.lerp(amber, other.amber, t)!,
      coral: Color.lerp(coral, other.coral, t)!,
      turquoise: Color.lerp(turquoise, other.turquoise, t)!,
      subtleGreen: Color.lerp(subtleGreen, other.subtleGreen, t)!,
      subtleAmber: Color.lerp(subtleAmber, other.subtleAmber, t)!,
      subtleCoral: Color.lerp(subtleCoral, other.subtleCoral, t)!,
      subtleTurquoise: Color.lerp(subtleTurquoise, other.subtleTurquoise, t)!,
      homeCardBackground: Color.lerp(homeCardBackground, other.homeCardBackground, t)!,
      homeCardBorder: Color.lerp(homeCardBorder, other.homeCardBorder, t)!,
      darkCardGradient: LinearGradient.lerp(darkCardGradient, other.darkCardGradient, t)!,
      homeCardGradient: LinearGradient.lerp(homeCardGradient, other.homeCardGradient, t),
    );
  }

  /// Paleta Botánica para Modo Claro
  static const BotanicalThemeColors light = BotanicalThemeColors(
    primary: Color(0xFF2E8B57),
    onPrimary: Color(0xFFFFFFFF),
    primaryContainer: Color(0xFFEAE5DC),
    onPrimaryContainer: Color(0xFF2E8B57),
    secondary: Color(0xFFE3A813),
    onSecondary: Color(0xFF7B5900),
    secondaryContainer: Color(0xFFEFE9E0),
    onSecondaryContainer: Color(0xFFE3A813),
    tertiary: Color(0xFF0B1D0F),
    onTertiary: Color(0xFFFFFFFF),
    appBackground: Color(0xFFFAF7F2),
    screenBackground: Color(0xFFFAF7F2),
    card: Color(0xFFFFFFFF),
    secondarySurface: Color(0xFFEAE5DC),
    textPrimary: Color(0xFF171717),
    textSecondary: Color(0xFF737373),
    border: Color(0xFFEAE5DC),
    error: Color(0xFFBA1A1A),
    onError: Color(0xFFFFFFFF),
    brightGreen: Color(0xFF2E8B57),
    amber: Color(0xFFE3A813),
    coral: Color(0xFFBA1A1A),
    turquoise: Color(0xFF00897B),
    subtleGreen: Color(0x1F2E8B57),
    subtleAmber: Color(0x1FE3A813),
    subtleCoral: Color(0x1FBA1A1A),
    subtleTurquoise: Color(0x1F00897B),
    homeCardBackground: Color(0xFFFFFFFF),
    homeCardBorder: Color(0xFFEAE5DC),
    darkCardGradient: LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [Color(0xFFFFFFFF), Color(0xFFFFFFFF)],
    ),
    homeCardGradient: null,
  );

  /// Paleta Botánica para Modo Oscuro
  static const BotanicalThemeColors dark = BotanicalThemeColors(
    primary: Color(0xFF437046),
    onPrimary: Color(0xFFFFFFFF),
    primaryContainer: Color(0xFF2A2A2A),
    onPrimaryContainer: Color(0xFF71B675),
    secondary: Color(0xFFE5B655),
    onSecondary: Color(0xFF161616),
    secondaryContainer: Color(0xFF2A2A2A),
    onSecondaryContainer: Color(0xFFE5B655),
    tertiary: Color(0xFFA1D3A0),
    onTertiary: Color(0xFF000000),
    appBackground: Color(0xFF161616),
    screenBackground: Color(0xFF1A1A1A),
    card: Color(0xFF242424),
    secondarySurface: Color(0xFF2A2A2A),
    textPrimary: Color(0xFFF4F4F4),
    textSecondary: Color(0xFFA0A0A0),
    border: Color(0xFF333333),
    error: Color(0xFFBA1A1A),
    onError: Color(0xFFFFFFFF),
    brightGreen: Color(0xFF71B675),
    amber: Color(0xFFE5B655),
    coral: Color(0xFFE8836B),
    turquoise: Color(0xFF4FC3B8),
    subtleGreen: Color(0x2971B675),
    subtleAmber: Color(0x29E5B655),
    subtleCoral: Color(0x29E8836B),
    subtleTurquoise: Color(0x294FC3B8),
    homeCardBackground: Color(0xFF1E2620),
    homeCardBorder: Color(0xFF2E3D31),
    darkCardGradient: LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [Color(0xFF1E3524), Color(0xFF242424)],
    ),
    homeCardGradient: LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [Color(0xFF202A22), Color(0xFF19221B)],
    ),
  );
}

/// Extensión de conveniencia en [BuildContext] para acceso declarativo inmediato
extension BotanicalThemeContext on BuildContext {
  /// Obtiene los tokens de diseño [BotanicalThemeColors] inyectados por el tema actual
  BotanicalThemeColors get botanicalColors {
    return Theme.of(this).extension<BotanicalThemeColors>() ??
        (Theme.of(this).brightness == Brightness.dark
            ? BotanicalThemeColors.dark
            : BotanicalThemeColors.light);
  }

  /// Determina reactivamente si el contexto actual corresponde a modo oscuro
  bool get isDarkMode => Theme.of(this).brightness == Brightness.dark;
}

/// Adaptador para retrocompatibilidad total con código preexistente
class AppColors {
  static bool isDark = false;

  static BotanicalThemeColors get _current =>
      isDark ? BotanicalThemeColors.dark : BotanicalThemeColors.light;

  // Primario
  static Color get primary => _current.primary;
  static Color get onPrimary => _current.onPrimary;
  static Color get primaryContainer => _current.primaryContainer;
  static Color get onPrimaryContainer => _current.onPrimaryContainer;
  static Color get primaryFixed => _current.primary;
  static Color get onPrimaryFixed => _current.onPrimaryContainer;

  // Verdes claros / Acentos
  static Color get lightGreen => _current.brightGreen;
  static Color get lightGreenAccent => _current.brightGreen;
  static Color get darkGreen => _current.tertiary;

  // Advertencia / Stock bajo
  static Color get warning => _current.secondary;
  static Color get onWarning => _current.onSecondary;
  static Color get secondary => _current.secondary;
  static Color get onSecondary => _current.onSecondary;
  static Color get secondaryContainer => _current.secondaryContainer;
  static Color get onSecondaryContainer => _current.onSecondaryContainer;

  // Terciario
  static Color get tertiary => _current.tertiary;
  static Color get onTertiary => _current.onTertiary;
  static Color get tertiaryContainer => _current.secondarySurface;

  // Fondos y Superficies
  static Color get appBackground => _current.appBackground;
  static Color get screenBackground => _current.screenBackground;
  static Color get surface => _current.screenBackground;

  // Tarjetas
  static Color get card => _current.card;
  static Color get surfaceContainerLowest => _current.card;

  // Tarjetas secundarias / campos / chips
  static Color get secondarySurface => _current.secondarySurface;
  static Color get surfaceContainerLow => _current.card;
  static Color get surfaceContainer => _current.secondarySurface;
  static Color get surfaceContainerHigh => _current.secondarySurface;
  static Color get surfaceContainerHighest => _current.border;
  static Color get surfaceVariant => _current.secondarySurface;

  // Textos
  static Color get textPrimary => _current.textPrimary;
  static Color get onSurface => _current.textPrimary;
  static Color get textSecondary => _current.textSecondary;
  static Color get onSurfaceVariant => _current.textSecondary;

  // Bordes y elementos inactivos
  static Color get border => _current.border;
  static Color get outline => _current.border;
  static Color get outlineVariant => _current.border;

  // Destructivo / Error
  static const Color error = Color(0xFFBA1A1A);
  static const Color onError = Color(0xFFFFFFFF);

  static Color get surfaceTint => _current.primary;

  // Módulo 7: Tokens de Acento para Modo Oscuro y Jerarquía Visual
  static Color get brightGreen => _current.brightGreen;
  static Color get amber => _current.amber;
  static Color get coral => _current.coral;
  static Color get turquoise => _current.turquoise;

  // Fondos tenues para círculos de opciones, alertas y chips
  static Color get subtleGreen => _current.subtleGreen;
  static Color get subtleAmber => _current.subtleAmber;
  static Color get subtleCoral => _current.subtleCoral;
  static Color get subtleTurquoise => _current.subtleTurquoise;

  // Degradado sutil para tarjetas principales en modo oscuro
  static LinearGradient get darkCardGradient => _current.darkCardGradient;

  // Tarjetas de Inicio (Dashboard): Matiz botánico reposado en modo oscuro
  static Color get homeCardBackground => _current.homeCardBackground;
  static Color get homeCardBorder => _current.homeCardBorder;
  static LinearGradient? get homeCardGradient => _current.homeCardGradient;
}

class AppTheme {
  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      extensions: const [
        BotanicalThemeColors.light,
      ],
      colorScheme: const ColorScheme.light(
        primary: Color(0xFF2E8B57),
        onPrimary: Color(0xFFFFFFFF),
        primaryContainer: Color(0xFFEAE5DC),
        onPrimaryContainer: Color(0xFF2E8B57),
        secondary: Color(0xFFE3A813),
        onSecondary: Color(0xFF7B5900),
        secondaryContainer: Color(0xFFEFE9E0),
        onSecondaryContainer: Color(0xFF7B5900),
        tertiary: Color(0xFF0B1D0F),
        onTertiary: Color(0xFFFFFFFF),
        surface: Color(0xFFFAF7F2),
        onSurface: Color(0xFF171717),
        onSurfaceVariant: Color(0xFF737373),
        error: AppColors.error,
        onError: AppColors.onError,
        outline: Color(0xFFEAE5DC),
        outlineVariant: Color(0xFFEAE5DC),
      ),
      scaffoldBackgroundColor: const Color(0xFFFAF7F2),
      cardColor: const Color(0xFFFFFFFF),
      fontFamily: 'Plus Jakarta Sans',
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: IconThemeData(color: Color(0xFF171717)),
        titleTextStyle: TextStyle(
          color: Color(0xFF171717),
          fontSize: 18,
          fontWeight: FontWeight.w600,
        ),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: Color(0xFFFFFFFF),
        modalBackgroundColor: Color(0xFFFFFFFF),
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
      ),
    );
  }

  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      extensions: const [
        BotanicalThemeColors.dark,
      ],
      colorScheme: const ColorScheme.dark(
        primary: Color(0xFF437046),
        onPrimary: Color(0xFFFFFFFF),
        primaryContainer: Color(0xFF2A2A2A),
        onPrimaryContainer: Color(0xFF71B675),
        secondary: Color(0xFFE5B655),
        onSecondary: Color(0xFF161616),
        secondaryContainer: Color(0xFF2A2A2A),
        onSecondaryContainer: Color(0xFFE5B655),
        tertiary: Color(0xFFA1D3A0),
        onTertiary: Color(0xFF000000),
        surface: Color(0xFF1A1A1A),
        onSurface: Color(0xFFF4F4F4),
        onSurfaceVariant: Color(0xFFA0A0A0),
        error: AppColors.error,
        onError: AppColors.onError,
        outline: Color(0xFF333333),
        outlineVariant: Color(0xFF333333),
      ),
      scaffoldBackgroundColor: const Color(0xFF1A1A1A),
      cardColor: const Color(0xFF242424),
      fontFamily: 'Plus Jakarta Sans',
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: IconThemeData(color: Color(0xFFF4F4F4)),
        titleTextStyle: TextStyle(
          color: Color(0xFFF4F4F4),
          fontSize: 18,
          fontWeight: FontWeight.w600,
        ),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: Color(0xFF242424),
        modalBackgroundColor: Color(0xFF242424),
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
      ),
    );
  }
}
