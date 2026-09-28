import 'trace_art_data.dart';
import 'trace_art_model.dart';

/// Draw Together content: every template is a PAIR of drawings shown side by
/// side. Seat 0 (the player who opened the room) colours the left drawing,
/// seat 1 the right one.

class DtCategory {
  final String id;
  final String key; // translation key
  final String? emoji; // shown before the name (optional)
  const DtCategory(this.id, this.key, this.emoji);
}

/// Same order as the reference app.
const List<DtCategory> kDtCategories = [
  DtCategory('popular', 'c_popular', null),
  DtCategory('cartoon', 'i_cartoon', '🧸'),
  DtCategory('anime', 'i_anime', null),
  DtCategory('worldcup', 'i_worldcup', null),
  DtCategory('seasonal', 'c_seasonal', null),
  DtCategory('animal', 'i_animal', '🐥'),
  DtCategory('food', 'i_food', '🍔'),
  DtCategory('kpop', 'i_kpop', null),
  DtCategory('plant', 'c_plant', '🌸'),
];

class DtTemplate {
  final String id;
  final String category;
  final String left;
  final String right;
  const DtTemplate(this.id, this.category, this.left, this.right);

  String artIdFor(int seat) => seat == 0 ? left : right;
  TraceArt artFor(int seat) => kTraceArt[artIdFor(seat)]!;
  TraceArt get leftArt => kTraceArt[left]!;
  TraceArt get rightArt => kTraceArt[right]!;
}

const List<DtTemplate> kDtTemplates = [
  // food (8)
  DtTemplate('dt_food_1', 'food', 'dt_food_icecream_a', 'dt_food_icecream_b'),
  DtTemplate('dt_food_2', 'food', 'dt_food_donut_a', 'dt_food_donut_b'),
  DtTemplate('dt_food_3', 'food', 'dt_food_burger_a', 'dt_food_burger_b'),
  DtTemplate('dt_food_4', 'food', 'dt_food_sushi_a', 'dt_food_sushi_b'),
  DtTemplate('dt_food_5', 'food', 'dt_food_cupcake_a', 'dt_food_cupcake_b'),
  DtTemplate('dt_food_6', 'food', 'dt_food_milk_a', 'dt_food_milk_b'),
  DtTemplate('dt_food_7', 'food', 'beginner_toast', 'xmas_cocoa'),
  DtTemplate('dt_food_8', 'food', 'beginner_cherry', 'halloween_pizza'),
  // cartoon (12)
  DtTemplate('dt_cartoon_1', 'cartoon', 'cartoon_bow_bunny', 'cartoon_rocker_girl'),
  DtTemplate('dt_cartoon_2', 'cartoon', 'cartoon_avocado_buddy', 'cartoon_leaf_witch'),
  DtTemplate('dt_cartoon_3', 'cartoon', 'cartoon_lion_hug', 'cartoon_cloud_puppy'),
  DtTemplate('dt_cartoon_4', 'cartoon', 'cartoon_waffle_bear', 'cartoon_hood_kitty'),
  DtTemplate('dt_cartoon_5', 'cartoon', 'cartoon_block_buddy', 'cartoon_jester_girl'),
  DtTemplate('dt_cartoon_6', 'cartoon', 'cartoon_hedgehog_racer', 'cartoon_bat_bunny'),
  DtTemplate('dt_cartoon_7', 'cartoon', 'cartoon_duck_detective', 'cartoon_winged_puff'),
  DtTemplate('dt_cartoon_8', 'cartoon', 'cartoon_robo_rabbit', 'cartoon_best_buds'),
  DtTemplate('dt_cartoon_9', 'cartoon', 'cartoon_candy_unicorn', 'cartoon_fuzzy_monster'),
  DtTemplate('dt_cartoon_10', 'cartoon', 'cartoon_headphone_shroom', 'cartoon_sprout_bug'),
  DtTemplate('dt_cartoon_11', 'cartoon', 'cartoon_jelly_blob', 'cartoon_bee_block'),
  DtTemplate('dt_cartoon_12', 'cartoon', 'cartoon_grumpy_toast', 'cartoon_space_alien'),
  // anime (12)
  DtTemplate('dt_anime_1', 'anime', 'anime_star_girl', 'anime_sakura_schoolgirl'),
  DtTemplate('dt_anime_2', 'anime', 'anime_ninja_kid', 'anime_idol_singer'),
  DtTemplate('dt_anime_3', 'anime', 'anime_cat_ear_girl', 'anime_witch_apprentice'),
  DtTemplate('dt_anime_4', 'anime', 'anime_knight_boy', 'anime_dragon_kid'),
  DtTemplate('dt_anime_5', 'anime', 'anime_spirit_fox', 'anime_forest_spirit'),
  DtTemplate('dt_anime_6', 'anime', 'anime_oni_kid', 'anime_bakery_girl'),
  DtTemplate('dt_anime_7', 'anime', 'anime_ramen_boy', 'anime_samurai_cat'),
  DtTemplate('dt_anime_8', 'anime', 'anime_magic_boy', 'anime_sleepy_student'),
  DtTemplate('dt_anime_9', 'anime', 'anime_flower_fairy', 'anime_robot_pilot'),
  DtTemplate('dt_anime_10', 'anime', 'anime_archer_girl', 'anime_ghost_girl'),
  DtTemplate('dt_anime_11', 'anime', 'anime_cloud_bunny', 'anime_tiger_hood_kid'),
  DtTemplate('dt_anime_12', 'anime', 'anime_chef_kid', 'anime_music_boy'),
  // kpop (6)
  DtTemplate('dt_kpop_1', 'kpop', 'dt_kpop_duo1_a', 'dt_kpop_duo1_b'),
  DtTemplate('dt_kpop_2', 'kpop', 'dt_kpop_dance_a', 'dt_kpop_dance_b'),
  DtTemplate('dt_kpop_3', 'kpop', 'dt_kpop_heart_a', 'dt_kpop_heart_b'),
  DtTemplate('dt_kpop_4', 'kpop', 'dt_kpop_light_a', 'dt_kpop_light_b'),
  DtTemplate('dt_kpop_5', 'kpop', 'dt_kpop_stage_a', 'dt_kpop_stage_b'),
  DtTemplate('dt_kpop_6', 'kpop', 'dt_kpop_cat_a', 'dt_kpop_cat_b'),
  // worldcup (6)
  DtTemplate('dt_worldcup_1', 'worldcup', 'dt_wc_kick_a', 'dt_wc_kick_b'),
  DtTemplate('dt_worldcup_2', 'worldcup', 'dt_wc_jersey_a', 'dt_wc_jersey_b'),
  DtTemplate('dt_worldcup_3', 'worldcup', 'dt_wc_cup_a', 'dt_wc_cup_b'),
  DtTemplate('dt_worldcup_4', 'worldcup', 'dt_wc_fans_a', 'dt_wc_fans_b'),
  DtTemplate('dt_worldcup_5', 'worldcup', 'dt_wc_boot_a', 'dt_wc_boot_b'),
  DtTemplate('dt_worldcup_6', 'worldcup', 'dt_wc_mascot_a', 'dt_wc_mascot_b'),
  // trending (6)
  DtTemplate('dt_trending_1', 'animal', 'trending_crow_coffee', 'trending_cow_float'),
  DtTemplate('dt_trending_2', 'animal', 'trending_cactus_elephant', 'trending_drum_log'),
  DtTemplate('dt_trending_3', 'animal', 'trending_coconut_elephant', 'trending_cat_fish'),
  DtTemplate('dt_trending_4', 'animal', 'trending_melon_giraffe', 'trending_banana_monkey'),
  DtTemplate('dt_trending_5', 'animal', 'trending_coconut_penguin', 'trending_fridge_camel'),
  DtTemplate('dt_trending_6', 'animal', 'trending_sneaker_shark', 'trending_tire_frog'),
  // animal (9)
  DtTemplate('dt_animal_1', 'animal', 'animal_bat', 'animal_bear'),
  DtTemplate('dt_animal_2', 'animal', 'animal_beluga', 'animal_chick'),
  DtTemplate('dt_animal_3', 'animal', 'animal_rooster', 'animal_dolphin'),
  DtTemplate('dt_animal_4', 'animal', 'animal_penguin', 'animal_canary'),
  DtTemplate('dt_animal_5', 'animal', 'animal_kitten', 'animal_turtle'),
  DtTemplate('dt_animal_6', 'animal', 'animal_duckling', 'animal_fawn'),
  DtTemplate('dt_animal_7', 'animal', 'animal_fennec_fox', 'animal_kiwi_bird'),
  DtTemplate('dt_animal_8', 'animal', 'animal_mockingbird', 'animal_pufferfish'),
  DtTemplate('dt_animal_9', 'animal', 'animal_parakeet', 'animal_snail'),
  // character (8)
  DtTemplate('dt_character_1', 'seasonal', 'xmas_santa_penguin', 'xmas_santa'),
  DtTemplate('dt_character_2', 'seasonal', 'xmas_reindeer', 'xmas_snowman'),
  DtTemplate('dt_character_3', 'seasonal', 'xmas_gingerbread', 'xmas_ornament'),
  DtTemplate('dt_character_4', 'seasonal', 'halloween_ghost_puppy', 'halloween_witch_ghost'),
  DtTemplate('dt_character_5', 'seasonal', 'halloween_franken', 'halloween_vampire'),
  DtTemplate('dt_character_6', 'seasonal', 'halloween_witch_kitty', 'halloween_witch_bunny'),
  DtTemplate('dt_character_7', 'seasonal', 'halloween_pumpkin_bunny', 'halloween_ghost'),
  DtTemplate('dt_character_8', 'seasonal', 'halloween_pumpkin_hat', 'halloween_candle'),
  // plant (7)
  DtTemplate('dt_plant_1', 'plant', 'dt_plant_tulip_a', 'dt_plant_tulip_b'),
  DtTemplate('dt_plant_2', 'plant', 'dt_plant_sun_a', 'dt_plant_sun_b'),
  DtTemplate('dt_plant_3', 'plant', 'dt_plant_cactus_a', 'dt_plant_cactus_b'),
  DtTemplate('dt_plant_4', 'plant', 'dt_plant_rose_a', 'dt_plant_rose_b'),
  DtTemplate('dt_plant_5', 'plant', 'dt_plant_tree_a', 'dt_plant_tree_b'),
  DtTemplate('dt_plant_6', 'plant', 'dt_plant_bouquet_a', 'dt_plant_bouquet_b'),
  DtTemplate('dt_plant_7', 'plant', 'beginner_mushroom', 'xmas_tree'),
];

/// "Popular" mixes the first pictures of every category (round robin).
List<DtTemplate> dtTemplatesFor(String category) {
  if (category != 'popular') {
    return kDtTemplates.where((t) => t.category == category).toList();
  }
  final lists = [
    for (final c in kDtCategories)
      if (c.id != 'popular') dtTemplatesFor(c.id).take(3).toList()
  ];
  final out = <DtTemplate>[];
  for (var i = 0; i < 3; i++) {
    for (final l in lists) {
      if (i < l.length) out.add(l[i]);
    }
  }
  return out;
}

DtTemplate dtTemplateById(String id) => kDtTemplates
    .firstWhere((t) => t.id == id, orElse: () => kDtTemplates.first);
