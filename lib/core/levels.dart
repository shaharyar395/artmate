import 'package:flutter/material.dart';

/// One level on the "Your Level" map. Unlocked when lessons >= [lessons].
class Level {
  final String key; // translation key
  final int lessons;
  final List<Color> colors; // badge colors when unlocked (light -> dark)
  const Level(this.key, this.lessons, this.colors);
}

/// Same 12 levels and lesson thresholds as the reference app.
const List<Level> kLevels = [
  Level('lv_novice', 1, [Color(0xFFE6B489), Color(0xFFB0713F)]),
  Level('lv_apprentice', 3, [Color(0xFFE3A06A), Color(0xFFA8602C)]),
  Level('lv_budding', 5, [Color(0xFFB6F07A), Color(0xFF4FB63A)]),
  Level('lv_emerging', 10, [Color(0xFF8FEAC0), Color(0xFF22A87A)]),
  Level('lv_developing', 20, [Color(0xFF9FDBFF), Color(0xFF2C8BE0)]),
  Level('lv_skilled', 30, [Color(0xFFB7C3FF), Color(0xFF4A5FE0)]),
  Level('lv_proficient', 40, [Color(0xFFE1C0FF), Color(0xFF8A43E0)]),
  Level('lv_accomplished', 50, [Color(0xFFFFB9E1), Color(0xFFD83C9A)]),
  Level('lv_master', 60, [Color(0xFFFFE27A), Color(0xFFE0A100)]),
  Level('lv_expert', 80, [Color(0xFFFFB38A), Color(0xFFE55A1C)]),
  Level('lv_virtuoso', 100, [Color(0xFFFF9FA6), Color(0xFFD2203A)]),
  Level('lv_legendary', 120, [Color(0xFFD9FBFF), Color(0xFF5BC8E8)]),
];

/// Index of the highest unlocked level, or -1 if none yet.
int currentLevelIndex(int lessons) {
  var idx = -1;
  for (var i = 0; i < kLevels.length; i++) {
    if (lessons >= kLevels[i].lessons) idx = i;
  }
  return idx;
}

/// Name shown on the profile ("Novice" until the first level unlocks).
String levelNameKey(int lessons) {
  final i = currentLevelIndex(lessons);
  return kLevels[i < 0 ? 0 : i].key;
}
