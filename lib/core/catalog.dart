import 'package:flutter/material.dart';

/// Static content for onboarding & profile.
///
/// Every item has an [asset] name. Drop a PNG with that name into
/// `assets/images/` and it replaces the emoji placeholder automatically.

class AgeRange {
  final String label;
  final Color circle;
  const AgeRange(this.label, this.circle);
}

const List<AgeRange> kAges = [
  AgeRange('1 – 4', Color(0xFFD7F5FB)),
  AgeRange('5 – 12', Color(0xFFFCF8D2)),
  AgeRange('13 – 17', Color(0xFFE1F8DB)),
  AgeRange('18 – 24', Color(0xFFF3E1FB)),
  AgeRange('25 – 34', Color(0xFFFDEFDD)),
  AgeRange('35+', Color(0xFFFBDFE8)),
];

class Purpose {
  final String key;
  final String emoji;
  final String asset;
  const Purpose(this.key, this.emoji, this.asset);
}

const List<Purpose> kPurposes = [
  Purpose('p_relax', '🖌️', 'purpose_relax.png'),
  Purpose('p_connect', '👩‍🎨', 'purpose_connect.png'),
  Purpose('p_improve', '📝', 'purpose_improve.png'),
  Purpose('p_kids', '🖍️', 'purpose_kids.png'),
  Purpose('p_health', '💖', 'purpose_health.png'),
  Purpose('p_other', '🎨', 'purpose_other.png'),
];

class Interest {
  final String id;
  final String key;
  final String emoji;
  final Color bg;
  final String asset;
  const Interest(this.id, this.key, this.emoji, this.bg, this.asset);
}

const List<Interest> kInterests = [
  Interest('animal', 'i_animal', '🐱', Color(0xFFFFF1F1), 'interest_animal.png'),
  Interest('food', 'i_food', '🍓', Color(0xFFFFE3E6), 'interest_food.png'),
  Interest('cartoon', 'i_cartoon', '🐻', Color(0xFFFFF4DC), 'interest_cartoon.png'),
  Interest('anime', 'i_anime', '🧚', Color(0xFFE3F8F8), 'interest_anime.png'),
  Interest('kpop', 'i_kpop', '🎤', Color(0xFFF3E8FF), 'interest_kpop.png'),
  Interest('plant', 'i_plant', '🌷', Color(0xFFEFFBEA), 'interest_plant.png'),
  Interest('worldcup', 'i_worldcup', '⚽', Color(0xFFDDF2FF), 'interest_worldcup.png'),
  Interest('seasonal', 'i_seasonal', '🔥', Color(0xFF1E2A5A), 'interest_seasonal.png'),
];

/// Profile avatars (index stored in AppState.avatarIndex).
const List<String> kAvatars = [
  '🐱', '🐶', '🐰', '🐼', '🦊', '🐻', '🐨', '🐯', '🐸', '🐵', '🐧', '🦄'
];
