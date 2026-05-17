import 'package:flutter/material.dart';

class ColorPalette {
  const ColorPalette({
    required this.cDark,
    required this.cForest,
    required this.cOlive,
    required this.cBright,
    required this.cTan,
    required this.cSand,
    required this.cCream,
    required this.cMud,
    required this.cText,
    required this.cText2,
    required this.cBorder,
    required this.cCard,
    required this.inputBg,
    required this.inputBorder,
    required this.inputText,
    required this.inputHint,
  });

  final Color cDark;
  final Color cForest;
  final Color cOlive;
  final Color cBright;
  final Color cTan;
  final Color cSand;
  final Color cCream;
  final Color cMud;
  final Color cText;
  final Color cText2;
  final Color cBorder;
  final Color cCard;
  final Color inputBg;
  final Color inputBorder;
  final Color inputText;
  final Color inputHint;
}

class AppPalettes {
  const AppPalettes._();

  static const camo = ColorPalette(
    cDark: Color(0xFF1C3010),
    cForest: Color(0xFF2E4D18),
    cOlive: Color(0xFF4E6B22),
    cBright: Color(0xFF7A9A28),
    cTan: Color(0xFFC48C28),
    cSand: Color(0xFFD4A84A),
    cCream: Color(0xFFF4F0E2),
    cMud: Color(0xFF3A2C08),
    cText: Color(0xFF1A2408),
    cText2: Color(0xFF556030),
    cBorder: Color(0xFFC8BE98),
    cCard: Color(0xFFFDFAF0),
    inputBg: Color(0xFF243018),
    inputBorder: Color(0xFF3A4E20),
    inputText: Color(0xFFD4CCA8),
    inputHint: Color(0xFF6A7840),
  );

  static const oliveNight = ColorPalette(
    cDark: Color(0xFF141D0E),
    cForest: Color(0xFF243715),
    cOlive: Color(0xFF35511D),
    cBright: Color(0xFF5D7D25),
    cTan: Color(0xFF9E6F1E),
    cSand: Color(0xFFC79A44),
    cCream: Color(0xFFEEE9DA),
    cMud: Color(0xFF2B1F06),
    cText: Color(0xFF121807),
    cText2: Color(0xFF49572E),
    cBorder: Color(0xFFB7AD89),
    cCard: Color(0xFFF8F3E6),
    inputBg: Color(0xFF1D2813),
    inputBorder: Color(0xFF32441E),
    inputText: Color(0xFFD5CCAB),
    inputHint: Color(0xFF61723E),
  );

  // Switch this one line later to change full app color theme.
  static const active = camo;
}

class AppColors {
  const AppColors._();

  // Active tokens used by UI. To switch theme later, replace these values
  // using one of the palettes above (e.g., AppPalettes.oliveNight).
  static const g1 = Color(0xFF1C3010);
  static const g2 = Color(0xFF2E4D18);
  static const g3 = Color(0xFF4E6B22);
  static const g4 = Color(0xFF7A9A28);
  static const g5 = Color(0xFF7A9A28);
  static const tan = Color(0xFFC48C28);
  static const gold = Color(0xFFD4A84A);
  static const goldLight = Color(0xFFD4A84A);
  static const goldDark = Color(0xFFC48C28);
  static const cream = Color(0xFFF4F0E2);
  static const card = Color(0xFFFDFAF0);
  static const border = Color(0xFFC8BE98);
  static const mud = Color(0xFF3A2C08);
  static const inputBg = Color(0xFF243018);
  static const inputBord = Color(0xFF3A4E20);
  static const inputText = Color(0xFFD4CCA8);
  static const inputHint = Color(0xFF6A7840);
  static const textPrimary = Color(0xFF1A2408);
  static const textSecondary = Color(0xFF556030);
  static const textMuted = Color(0xFF556030);

  // Crimson palette — used for onboarding headers and splash
  static const crimson = Color(0xFF7B1414);
  static const crimsonDark = Color(0xFF5C0F0F);
  static const crimsonMuted = Color(0xFFB44040);
}
