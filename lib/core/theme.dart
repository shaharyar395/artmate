import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Colors sampled from the reference screen recording.
class AppColors {
  static const splashBlue = Color(0xFF0A86F4);
  static const splashBlueLight = Color(0xFF2C9BFA);

  static const blue = Color(0xFF3A9BFD); // Continue button
  static const blueDark = Color(0xFF1F74D8); // Continue button bottom edge
  static const selectBlue = Color(0xFF2F86EE); // selected borders / checks
  static const selectBg = Color(0xFFEAF5FF);
  static const progress = Color(0xFF2D86E8);

  static const text = Color(0xFF1E1E1E);
  static const textSoft = Color(0xFF3A3A3A);
  static const sub = Color(0xFF6B6B6B);
  static const border = Color(0xFFE9ECEF);
  static const radio = Color(0xFFC9CDD2);

  static const disabled = Color(0xFFE4E4EE);
  static const disabledDark = Color(0xFFC6C6D4);

  static const lobbyBg = Color(0xFFF2FAFF);
  static const settingsBg = Color(0xFFEEFAFE);
  static const profileTop = Color(0xFFBDEEFF);
  static const titleBlue = Color(0xFF3A9BFD);

  static const switchGreen = Color(0xFF34C63A);
  static const levelBlue = Color(0xFF1E6FE0);

  static const premiumA = Color(0xFFFFA928);
  static const premiumB = Color(0xFFFF7A00);

  static const langScreenBlue = Color(0xFF0A82F3);
  static const langSelectedA = Color(0xFFFFD24A);
  static const langSelectedB = Color(0xFFFFB300);
  static const pinkBtn = Color(0xFFE58CF4);
  static const greenBtn = Color(0xFF52CE35);

  static const rateGreenA = Color(0xFF7BF542);
  static const rateGreenB = Color(0xFF22CF0E);
  static const rateGreenDark = Color(0xFF159A0A);
}

/// Body font (Nunito — matches the rounded sans used across the app).
TextStyle nunito(double size,
        {FontWeight weight = FontWeight.w700,
        Color color = AppColors.text,
        double? height}) =>
    GoogleFonts.nunito(
        fontSize: size, fontWeight: weight, color: color, height: height);

/// Chunky display font used for titles like "Profile", "Setting", banners.
TextStyle display(double size, {Color color = Colors.white, double? height}) =>
    GoogleFonts.lilitaOne(fontSize: size, color: color, height: height);

ThemeData buildTheme() {
  final base = ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(seedColor: AppColors.blue),
    scaffoldBackgroundColor: Colors.white,
    splashFactory: InkRipple.splashFactory,
  );
  return base.copyWith(
    textTheme: GoogleFonts.nunitoTextTheme(base.textTheme),
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.all(Colors.white),
      trackColor: WidgetStateProperty.resolveWith((s) =>
          s.contains(WidgetState.selected)
              ? AppColors.switchGreen
              : const Color(0xFFD5D8DC)),
      trackOutlineColor: WidgetStateProperty.all(Colors.transparent),
    ),
  );
}
