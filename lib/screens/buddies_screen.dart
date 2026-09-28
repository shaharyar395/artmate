import 'package:flutter/material.dart';

import '../core/app_state.dart';
import '../core/catalog.dart';
import '../core/strings.dart';
import '../core/theme.dart';
import '../widgets/common.dart';
import 'draw_together_screen.dart';

/// "My buddies": people you've drawn with, or an empty state with
/// "Find a new buddy" (opens Draw Together).
class BuddiesScreen extends StatelessWidget {
  const BuddiesScreen({super.key});

  String _ago(BuildContext context, int ms) {
    final d = DateTime.now()
        .difference(DateTime.fromMillisecondsSinceEpoch(ms));
    if (d.inMinutes < 1) return tr(context, 'justNow');
    if (d.inHours < 1) return tr(context, 'minutesAgo', {'n': '${d.inMinutes}'});
    if (d.inDays < 1) return tr(context, 'hoursAgo', {'n': '${d.inHours}'});
    return tr(context, 'daysAgo', {'n': '${d.inDays}'});
  }

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final list = s.buddyList;
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
              child: Row(
                children: [
                  BackCircle(),
                  Expanded(
                    child: Center(
                      heightFactor: 1,
                      child: Text(tr(context, 'myBuddies'),
                          style: nunito(22,
                              weight: FontWeight.w700,
                              color: AppColors.titleBlue)),
                    ),
                  ),
                  const SizedBox(width: 38),
                ],
              ),
            ),
            Expanded(
              child: list.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 32),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const ArtSlot(
                              asset: 'buddies_empty.png',
                              fallback: Emoji('🧑‍🤝‍🧑', size: 110),
                            ),
                            const SizedBox(height: 18),
                            Text(tr(context, 'noBuddiesYet'),
                                style: nunito(19, weight: FontWeight.w800)),
                            const SizedBox(height: 6),
                            Text(tr(context, 'noBuddiesSub'),
                                textAlign: TextAlign.center,
                                style: nunito(15,
                                    weight: FontWeight.w500,
                                    color: AppColors.sub)),
                          ],
                        ),
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                      itemCount: list.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 10),
                      itemBuilder: (context, i) {
                        final b = list[i];
                        return Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 10),
                          decoration: BoxDecoration(
                            color: AppColors.settingsBg,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 48,
                                height: 48,
                                decoration: const BoxDecoration(
                                    color: Colors.white,
                                    shape: BoxShape.circle),
                                alignment: Alignment.center,
                                child: Emoji(
                                    kAvatars[b.avatar % kAvatars.length],
                                    size: 30),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  children: [
                                    Text(b.name,
                                        style: nunito(17,
                                            weight: FontWeight.w800)),
                                    Text(
                                        '${tr(context, 'drewTogether')} · ${_ago(context, b.lastDrawn)}',
                                        style: nunito(13,
                                            weight: FontWeight.w500,
                                            color: AppColors.sub)),
                                  ],
                                ),
                              ),
                              const Emoji('🎨', size: 24),
                            ],
                          ),
                        );
                      },
                    ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 18),
              child: Pressable(
                onTap: () => Navigator.of(context).pushReplacement(
                    slideRoute(const DrawTogetherScreen())),
                child: Container(
                  height: 52,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: const Color(0xFF1673FF),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(tr(context, 'findNewBuddy'),
                      style: nunito(17,
                          weight: FontWeight.w600, color: Colors.white)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
