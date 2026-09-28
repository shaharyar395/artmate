import 'package:flutter/material.dart';

/// Drawing templates shown on the Draw Together page.
///
/// Drop `assets/images/tpl_<id>.png` in to replace the emoji placeholder.
class DrawTemplate {
  final String id;
  final String category;
  final String emoji;
  final Color bg;
  final int players;
  final bool popular;
  const DrawTemplate(this.id, this.category, this.emoji, this.bg,
      {this.players = 2, this.popular = false});
}

class TemplateCategory {
  final String id; // 'popular' or an interest id
  final String key; // translation key
  final String emoji;
  const TemplateCategory(this.id, this.key, this.emoji);
}

/// Chip order matches the reference app.
const List<TemplateCategory> kTemplateCategories = [
  TemplateCategory('popular', 'popular', '✨'),
  TemplateCategory('food', 'i_food', '🍔'),
  TemplateCategory('cartoon', 'i_cartoon', '🐻'),
  TemplateCategory('anime', 'i_anime', '🧚'),
  TemplateCategory('plant', 'i_plant', '🌸'),
  TemplateCategory('seasonal', 'i_seasonal', '🍂'),
  TemplateCategory('animal', 'i_animal', '🐱'),
  TemplateCategory('kpop', 'i_kpop', '🎤'),
  TemplateCategory('worldcup', 'i_worldcup', '⚽'),
];

const List<DrawTemplate> kTemplates = [
  // food
  DrawTemplate('food_1', 'food', '🍩', Color(0xFFFFE3EC), popular: true),
  DrawTemplate('food_2', 'food', '🍞', Color(0xFFFFD6DE), popular: true),
  DrawTemplate('food_3', 'food', '🍉', Color(0xFFFFF4E0), popular: true),
  DrawTemplate('food_4', 'food', '🍦', Color(0xFFEAF2FF)),
  DrawTemplate('food_5', 'food', '🍒', Color(0xFFFFEEF0)),
  DrawTemplate('food_6', 'food', '🧋', Color(0xFFFFF1E6)),
  // cartoon
  DrawTemplate('cartoon_1', 'cartoon', '🐰', Color(0xFFFFD9DF), popular: true),
  DrawTemplate('cartoon_2', 'cartoon', '⭐', Color(0xFFFFF8E1), popular: true),
  DrawTemplate('cartoon_3', 'cartoon', '🐶', Color(0xFFE8F6FF)),
  DrawTemplate('cartoon_4', 'cartoon', '🐥', Color(0xFFFFFBE0), popular: true),
  DrawTemplate('cartoon_5', 'cartoon', '🦕', Color(0xFFE6F8E6)),
  DrawTemplate('cartoon_6', 'cartoon', '🦢', Color(0xFFF1F7FF)),
  // anime
  DrawTemplate('anime_1', 'anime', '🧚', Color(0xFFDDF7F5), popular: true),
  DrawTemplate('anime_2', 'anime', '👧', Color(0xFFFFE0EC)),
  DrawTemplate('anime_3', 'anime', '🦊', Color(0xFFFFEFE0)),
  DrawTemplate('anime_4', 'anime', '🐉', Color(0xFFE6F0FF)),
  // plant
  DrawTemplate('plant_1', 'plant', '🌷', Color(0xFFF2FBEF), popular: true),
  DrawTemplate('plant_2', 'plant', '🌻', Color(0xFFFFF9DD)),
  DrawTemplate('plant_3', 'plant', '🌵', Color(0xFFEAF8EC)),
  DrawTemplate('plant_4', 'plant', '🍄', Color(0xFFFFECEC)),
  // seasonal
  DrawTemplate('seasonal_1', 'seasonal', '🔥', Color(0xFF1E2A5A), popular: true),
  DrawTemplate('seasonal_2', 'seasonal', '☂️', Color(0xFFE5F6EA), popular: true),
  DrawTemplate('seasonal_3', 'seasonal', '🎃', Color(0xFFFFEEDD)),
  DrawTemplate('seasonal_4', 'seasonal', '⛄', Color(0xFFE8F4FF)),
  // animal
  DrawTemplate('animal_1', 'animal', '🐢', Color(0xFF1C6F8F), popular: true),
  DrawTemplate('animal_2', 'animal', '🐈‍⬛', Color(0xFFF1EEFF), popular: true),
  DrawTemplate('animal_3', 'animal', '🐹', Color(0xFFFFF3E3), popular: true),
  DrawTemplate('animal_4', 'animal', '🐱', Color(0xFFFFE4EC)),
  DrawTemplate('animal_5', 'animal', '🐧', Color(0xFFE6F4FF)),
  // kpop
  DrawTemplate('kpop_1', 'kpop', '🎤', Color(0xFFF3E8FF), popular: true),
  DrawTemplate('kpop_2', 'kpop', '💃', Color(0xFFFFE6F2)),
  DrawTemplate('kpop_3', 'kpop', '🕺', Color(0xFFE8ECFF)),
  // world cup
  DrawTemplate('worldcup_1', 'worldcup', '⚽', Color(0xFFDDF2FF), popular: true),
  DrawTemplate('worldcup_2', 'worldcup', '🏆', Color(0xFFFFF6D6)),
  DrawTemplate('worldcup_3', 'worldcup', '👕', Color(0xFFE8F0FF)),
];

List<DrawTemplate> templatesFor(String category) => category == 'popular'
    ? kTemplates.where((t) => t.popular).toList()
    : kTemplates.where((t) => t.category == category).toList();
