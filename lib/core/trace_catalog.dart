import 'package:flutter/material.dart';

import 'trace_art_data.dart';
import 'trace_art_model.dart';

/// Content for the Trace Art page.
///
/// Every picture is an original vector drawing in trace_art_data.dart; its
/// guide parts are the tracing steps. Carousel slides can be replaced with
/// `assets/images/trace_banner_<n>.png` (1-based).

class TraceBanner {
  final String title;
  final String emoji;
  final List<Color> colors;
  final String traceId; // item opened by the "Draw" button
  const TraceBanner(this.title, this.emoji, this.colors, this.traceId);
}

const List<TraceBanner> kTraceBanners = [
  TraceBanner('WINTER\nPENGUIN', '🐧', [Color(0xFFBDE9FF), Color(0xFF5CB8EE)],
      'xmas_santa_penguin'),
  TraceBanner('ANIME\nSTAR', '👧', [Color(0xFFFF6B6B), Color(0xFFE12D3F)],
      'anime_star_girl'),
  TraceBanner('FUNNY\nFRIENDS', '🥁', [Color(0xFFFFA23A), Color(0xFFD9570B)],
      'trending_drum_log'),
  TraceBanner('OCEAN\nFRIENDS', '🐬', [Color(0xFF3AA0F0), Color(0xFF0E4FA8)],
      'animal_dolphin'),
  TraceBanner('SPOOKY\nCHERRY', '🍒', [Color(0xFF6B4C9A), Color(0xFF2E2350)],
      'halloween_cherry'),
];

class TraceCategory {
  final String id;
  final String key; // translation key
  final String? emoji;
  const TraceCategory(this.id, this.key, this.emoji);
}

/// Same order as the reference app.
const List<TraceCategory> kTraceCategories = [
  TraceCategory('beginner', 'c_beginner', '🎃'),
  TraceCategory('trending', 'c_trending', '✨'),
  TraceCategory('cartoon', 'i_cartoon', '🐻'),
  TraceCategory('anime', 'i_anime', '🧚'),
  TraceCategory('animal', 'i_animal', '🐥'),
  TraceCategory('neon', 'c_neon', '❤️'),
  TraceCategory('xmas', 'c_xmas', '🎅'),
  TraceCategory('halloween', 'c_halloween', '🎃'),
];

class TraceItem {
  final String id;
  final String category;
  const TraceItem(this.id, this.category);

  bool get isNeon => category == 'neon';

  /// The drawing (always present for catalog items).
  TraceArt get art => kTraceArt[id] ?? kTraceArt.values.first;

}

const List<TraceItem> kTraceItems = [
  // beginner (13)
  TraceItem('beginner_pumpkin', 'beginner'),
  TraceItem('beginner_car', 'beginner'),
  TraceItem('beginner_cherry', 'beginner'),
  TraceItem('beginner_tiger', 'beginner'),
  TraceItem('beginner_chick', 'beginner'),
  TraceItem('beginner_bunny', 'beginner'),
  TraceItem('beginner_mushroom', 'beginner'),
  TraceItem('beginner_earth', 'beginner'),
  TraceItem('beginner_octopus', 'beginner'),
  TraceItem('beginner_starfish', 'beginner'),
  TraceItem('beginner_toast', 'beginner'),
  TraceItem('beginner_whale', 'beginner'),
  TraceItem('beginner_submarine', 'beginner'),
  // trending (12)
  TraceItem('trending_crow_coffee', 'trending'),
  TraceItem('trending_cow_float', 'trending'),
  TraceItem('trending_cactus_elephant', 'trending'),
  TraceItem('trending_drum_log', 'trending'),
  TraceItem('trending_coconut_elephant', 'trending'),
  TraceItem('trending_cat_fish', 'trending'),
  TraceItem('trending_melon_giraffe', 'trending'),
  TraceItem('trending_banana_monkey', 'trending'),
  TraceItem('trending_coconut_penguin', 'trending'),
  TraceItem('trending_fridge_camel', 'trending'),
  TraceItem('trending_sneaker_shark', 'trending'),
  TraceItem('trending_tire_frog', 'trending'),
  // cartoon (24)
  TraceItem('cartoon_bow_bunny', 'cartoon'),
  TraceItem('cartoon_rocker_girl', 'cartoon'),
  TraceItem('cartoon_avocado_buddy', 'cartoon'),
  TraceItem('cartoon_leaf_witch', 'cartoon'),
  TraceItem('cartoon_lion_hug', 'cartoon'),
  TraceItem('cartoon_cloud_puppy', 'cartoon'),
  TraceItem('cartoon_waffle_bear', 'cartoon'),
  TraceItem('cartoon_hood_kitty', 'cartoon'),
  TraceItem('cartoon_block_buddy', 'cartoon'),
  TraceItem('cartoon_jester_girl', 'cartoon'),
  TraceItem('cartoon_hedgehog_racer', 'cartoon'),
  TraceItem('cartoon_bat_bunny', 'cartoon'),
  TraceItem('cartoon_duck_detective', 'cartoon'),
  TraceItem('cartoon_winged_puff', 'cartoon'),
  TraceItem('cartoon_robo_rabbit', 'cartoon'),
  TraceItem('cartoon_best_buds', 'cartoon'),
  TraceItem('cartoon_candy_unicorn', 'cartoon'),
  TraceItem('cartoon_fuzzy_monster', 'cartoon'),
  TraceItem('cartoon_headphone_shroom', 'cartoon'),
  TraceItem('cartoon_sprout_bug', 'cartoon'),
  TraceItem('cartoon_jelly_blob', 'cartoon'),
  TraceItem('cartoon_bee_block', 'cartoon'),
  TraceItem('cartoon_grumpy_toast', 'cartoon'),
  TraceItem('cartoon_space_alien', 'cartoon'),
  // anime (24)
  TraceItem('anime_star_girl', 'anime'),
  TraceItem('anime_sakura_schoolgirl', 'anime'),
  TraceItem('anime_ninja_kid', 'anime'),
  TraceItem('anime_idol_singer', 'anime'),
  TraceItem('anime_cat_ear_girl', 'anime'),
  TraceItem('anime_witch_apprentice', 'anime'),
  TraceItem('anime_knight_boy', 'anime'),
  TraceItem('anime_dragon_kid', 'anime'),
  TraceItem('anime_spirit_fox', 'anime'),
  TraceItem('anime_forest_spirit', 'anime'),
  TraceItem('anime_oni_kid', 'anime'),
  TraceItem('anime_bakery_girl', 'anime'),
  TraceItem('anime_ramen_boy', 'anime'),
  TraceItem('anime_samurai_cat', 'anime'),
  TraceItem('anime_magic_boy', 'anime'),
  TraceItem('anime_sleepy_student', 'anime'),
  TraceItem('anime_flower_fairy', 'anime'),
  TraceItem('anime_robot_pilot', 'anime'),
  TraceItem('anime_archer_girl', 'anime'),
  TraceItem('anime_ghost_girl', 'anime'),
  TraceItem('anime_cloud_bunny', 'anime'),
  TraceItem('anime_tiger_hood_kid', 'anime'),
  TraceItem('anime_chef_kid', 'anime'),
  TraceItem('anime_music_boy', 'anime'),
  // animal (19)
  TraceItem('animal_bat', 'animal'),
  TraceItem('animal_bear', 'animal'),
  TraceItem('animal_beluga', 'animal'),
  TraceItem('animal_chick', 'animal'),
  TraceItem('animal_rooster', 'animal'),
  TraceItem('animal_dolphin', 'animal'),
  TraceItem('animal_penguin', 'animal'),
  TraceItem('animal_canary', 'animal'),
  TraceItem('animal_kitten', 'animal'),
  TraceItem('animal_turtle', 'animal'),
  TraceItem('animal_duckling', 'animal'),
  TraceItem('animal_fawn', 'animal'),
  TraceItem('animal_fennec_fox', 'animal'),
  TraceItem('animal_kiwi_bird', 'animal'),
  TraceItem('animal_mockingbird', 'animal'),
  TraceItem('animal_pufferfish', 'animal'),
  TraceItem('animal_parakeet', 'animal'),
  TraceItem('animal_snail', 'animal'),
  TraceItem('animal_bunny', 'animal'),
  // neon (30)
  TraceItem('neon_heart', 'neon'),
  TraceItem('neon_ring', 'neon'),
  TraceItem('neon_love_letter', 'neon'),
  TraceItem('neon_lips', 'neon'),
  TraceItem('neon_broken_heart', 'neon'),
  TraceItem('neon_chat_hearts', 'neon'),
  TraceItem('neon_heart_arrow', 'neon'),
  TraceItem('neon_pineapple', 'neon'),
  TraceItem('neon_cherries', 'neon'),
  TraceItem('neon_ice_cream', 'neon'),
  TraceItem('neon_donut', 'neon'),
  TraceItem('neon_cupcake', 'neon'),
  TraceItem('neon_dove', 'neon'),
  TraceItem('neon_shopping_bag', 'neon'),
  TraceItem('neon_winged_heart', 'neon'),
  TraceItem('neon_shooting_star', 'neon'),
  TraceItem('neon_lollipop', 'neon'),
  TraceItem('neon_music_hearts', 'neon'),
  TraceItem('neon_magic_wand', 'neon'),
  TraceItem('neon_piggy', 'neon'),
  TraceItem('neon_tomato', 'neon'),
  TraceItem('neon_bow_arrow', 'neon'),
  TraceItem('neon_diamond', 'neon'),
  TraceItem('neon_unicorn_cupcake', 'neon'),
  TraceItem('neon_rainbow_cone', 'neon'),
  TraceItem('neon_cheers', 'neon'),
  TraceItem('neon_crystal', 'neon'),
  TraceItem('neon_rainbow_heart', 'neon'),
  TraceItem('neon_flower_ring', 'neon'),
  TraceItem('neon_bouquet', 'neon'),
  // xmas (16)
  TraceItem('xmas_santa_penguin', 'xmas'),
  TraceItem('xmas_candy_cane', 'xmas'),
  TraceItem('xmas_santa', 'xmas'),
  TraceItem('xmas_tree', 'xmas'),
  TraceItem('xmas_reindeer', 'xmas'),
  TraceItem('xmas_bells', 'xmas'),
  TraceItem('xmas_snowman', 'xmas'),
  TraceItem('xmas_gift', 'xmas'),
  TraceItem('xmas_gingerbread', 'xmas'),
  TraceItem('xmas_stocking', 'xmas'),
  TraceItem('xmas_wreath', 'xmas'),
  TraceItem('xmas_ornament', 'xmas'),
  TraceItem('xmas_snowflake', 'xmas'),
  TraceItem('xmas_sleigh', 'xmas'),
  TraceItem('xmas_mittens', 'xmas'),
  TraceItem('xmas_cocoa', 'xmas'),
  // halloween (23)
  TraceItem('halloween_cherry', 'halloween'),
  TraceItem('halloween_ghost_puppy', 'halloween'),
  TraceItem('halloween_pumpkin_bunny', 'halloween'),
  TraceItem('halloween_pizza', 'halloween'),
  TraceItem('halloween_witch_ghost', 'halloween'),
  TraceItem('halloween_pumpkin_soda', 'halloween'),
  TraceItem('halloween_ghost', 'halloween'),
  TraceItem('halloween_franken', 'halloween'),
  TraceItem('halloween_vampire', 'halloween'),
  TraceItem('halloween_spider_cupcake', 'halloween'),
  TraceItem('halloween_cauldron', 'halloween'),
  TraceItem('halloween_sugar_skull', 'halloween'),
  TraceItem('halloween_witch_kitty', 'halloween'),
  TraceItem('halloween_witch_bunny', 'halloween'),
  TraceItem('halloween_spooky_cup', 'halloween'),
  TraceItem('halloween_skull_mug', 'halloween'),
  TraceItem('halloween_tombstone', 'halloween'),
  TraceItem('halloween_grave_cake', 'halloween'),
  TraceItem('halloween_pumpkin_hat', 'halloween'),
  TraceItem('halloween_candle', 'halloween'),
  TraceItem('halloween_ghost_laundry', 'halloween'),
  TraceItem('halloween_crystal_ball', 'halloween'),
  TraceItem('halloween_witch_hat', 'halloween'),
];

List<TraceItem> traceItemsFor(String category) =>
    kTraceItems.where((t) => t.category == category).toList();

/// Unknown ids (e.g. old album entries) fall back to the first picture.
TraceItem traceItemById(String id) =>
    kTraceItems.firstWhere((t) => t.id == id, orElse: () => kTraceItems.first);
