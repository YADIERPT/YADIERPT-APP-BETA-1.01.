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

class AppColors {
  static bool isDark = false;

  // Primario
  static Color get primary =>
      isDark ? const Color(0xFF437046) : const Color(0xFF2E8B57);
  static Color get onPrimary => const Color(0xFFFFFFFF);
  static Color get primaryContainer =>
      isDark ? const Color(0xFF2A2A2A) : const Color(0xFFEAE5DC);
  static Color get onPrimaryContainer =>
      isDark ? const Color(0xFF71B675) : const Color(0xFF2E8B57);
  static Color get primaryFixed =>
      isDark ? const Color(0xFF437046) : const Color(0xFF2E8B57);
  static Color get onPrimaryFixed =>
      isDark ? const Color(0xFFA1D3A0) : const Color(0xFF0B1D0F);

  // Verdes claros / Acentos
  static Color get lightGreen =>
      isDark ? const Color(0xFF71B675) : const Color(0xFF2E8B57);
  static Color get lightGreenAccent =>
      isDark ? const Color(0xFFA1D3A0) : const Color(0xFF0B1D0F);
  static Color get darkGreen =>
      isDark ? const Color(0xFFA1D3A0) : const Color(0xFF0B1D0F);

  // Advertencia / Stock bajo
  static Color get warning =>
      isDark ? const Color(0xFFE5B655) : const Color(0xFFE3A813);
  static Color get onWarning =>
      isDark ? const Color(0xFF161616) : const Color(0xFF7B5900);
  static Color get secondary => warning;
  static Color get onSecondary => onWarning;
  static Color get secondaryContainer =>
      isDark ? const Color(0xFF2A2A2A) : const Color(0xFFEFE9E0);
  static Color get onSecondaryContainer => warning;

  // Terciario
  static Color get tertiary => darkGreen;
  static Color get onTertiary => const Color(0xFFFFFFFF);
  static Color get tertiaryContainer =>
      isDark ? const Color(0xFF242424) : const Color(0xFFEAE5DC);

  // Fondos y Superficies
  static Color get appBackground =>
      isDark ? const Color(0xFF161616) : const Color(0xFFFAF7F2);
  static Color get screenBackground =>
      isDark ? const Color(0xFF1A1A1A) : const Color(0xFFFAF7F2);
  static Color get surface => screenBackground;

  // Tarjetas
  static Color get card =>
      isDark ? const Color(0xFF242424) : const Color(0xFFFFFFFF);
  static Color get surfaceContainerLowest => card;

  // Tarjetas secundarias / campos / chips
  static Color get secondarySurface =>
      isDark ? const Color(0xFF2A2A2A) : const Color(0xFFEAE5DC);
  static Color get surfaceContainerLow =>
      isDark ? const Color(0xFF242424) : const Color(0xFFFAF7F2);
  static Color get surfaceContainer =>
      isDark ? const Color(0xFF2A2A2A) : const Color(0xFFEAE5DC);
  static Color get surfaceContainerHigh =>
      isDark ? const Color(0xFF2A2A2A) : const Color(0xFFEFE9E0);
  static Color get surfaceContainerHighest =>
      isDark ? const Color(0xFF333333) : const Color(0xFFEAE5DC);
  static Color get surfaceVariant =>
      isDark ? const Color(0xFF2A2A2A) : const Color(0xFFEFE9E0);

  // Textos
  static Color get textPrimary =>
      isDark ? const Color(0xFFF4F4F4) : const Color(0xFF171717);
  static Color get onSurface => textPrimary;
  static Color get textSecondary =>
      isDark ? const Color(0xFFA0A0A0) : const Color(0xFF737373);
  static Color get onSurfaceVariant => textSecondary;

  // Bordes y elementos inactivos
  static Color get border =>
      isDark ? const Color(0xFF333333) : const Color(0xFFEAE5DC);
  static Color get outline => border;
  static Color get outlineVariant => border;

  // Destructivo / Error
  static const Color error = Color(0xFFBA1A1A);
  static const Color onError = Color(0xFFFFFFFF);

  static Color get surfaceTint =>
      isDark ? const Color(0xFF71B675) : const Color(0xFF2E8B57);

  // Módulo 7: Tokens de Acento para Modo Oscuro y Jerarquía Visual
  static Color get brightGreen =>
      isDark ? const Color(0xFF71B675) : const Color(0xFF2E8B57);
  static Color get amber =>
      isDark ? const Color(0xFFE5B655) : const Color(0xFFE3A813);
  static Color get coral =>
      isDark ? const Color(0xFFE8836B) : const Color(0xFFBA1A1A);
  static Color get turquoise =>
      isDark ? const Color(0xFF4FC3B8) : const Color(0xFF00897B);

  // Fondos tenues para círculos de opciones, alertas y chips
  static Color get subtleGreen =>
      isDark ? const Color(0xFF71B675).withValues(alpha: 0.16) : const Color(0xFF2E8B57).withValues(alpha: 0.12);
  static Color get subtleAmber =>
      isDark ? const Color(0xFFE5B655).withValues(alpha: 0.16) : const Color(0xFFE3A813).withValues(alpha: 0.12);
  static Color get subtleCoral =>
      isDark ? const Color(0xFFE8836B).withValues(alpha: 0.16) : const Color(0xFFBA1A1A).withValues(alpha: 0.12);
  static Color get subtleTurquoise =>
      isDark ? const Color(0xFF4FC3B8).withValues(alpha: 0.16) : const Color(0xFF00897B).withValues(alpha: 0.12);

  // Degradado sutil para tarjetas principales en modo oscuro
  static LinearGradient get darkCardGradient => isDark
      ? const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF1E3524), // Verde oscuro
            Color(0xFF242424), // Superficie de tarjeta
          ],
        )
      : const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFFFFFFFF),
            Color(0xFFFFFFFF),
          ],
        );
}

class AppTheme {
  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
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
    );
  }

  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
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
    );
  }
}
