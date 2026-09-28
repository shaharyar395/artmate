import 'package:flutter/material.dart';

import '../../core/app_state.dart';
import '../../core/catalog.dart';
import '../../core/strings.dart';
import '../../core/theme.dart';
import '../../widgets/common.dart';
import '../lobby_screen.dart';

/// Onboarding step 3: "Tell us what interests you" (multi-select, min 1).
class InterestsScreen extends StatefulWidget {
  const InterestsScreen({super.key});

  @override
  State<InterestsScreen> createState() => _InterestsScreenState();
}

class _InterestsScreenState extends State<InterestsScreen> {
  final Set<String> _selected = {};

  @override
  Widget build(BuildContext context) {
    return OnboardingScaffold(
      step: 3,
      title: tr(context, 'interestsTitle'),
      subtitle: tr(context, 'interestsSub'),
      canContinue: _selected.isNotEmpty,
      onContinue: () {
        final s = AppScope.read(context);
        s.setInterests({..._selected});
        s.completeOnboarding();
        Navigator.of(context).pushAndRemoveUntil(
            fadeRoute(const LobbyScreen()), (_) => false);
      },
      child: GridView.builder(
        padding: const EdgeInsets.fromLTRB(28, 6, 28, 12),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          mainAxisSpacing: 18,
          crossAxisSpacing: 18,
          childAspectRatio: 0.84,
        ),
        itemCount: kInterests.length,
        itemBuilder: (context, i) {
          final it = kInterests[i];
          final sel = _selected.contains(it.id);
          return Pressable(
            onTap: () => setState(() {
              sel ? _selected.remove(it.id) : _selected.add(it.id);
            }),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                    color: sel ? AppColors.selectBlue : AppColors.border,
                    width: sel ? 3 : 1.5),
              ),
              child: Stack(
                children: [
                  Column(
                    children: [
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(14, 14, 14, 4),
                          child: ArtSlot(
                            asset: it.asset,
                            fallback: Container(
                              decoration: BoxDecoration(
                                color: it.bg,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              alignment: Alignment.center,
                              child: Emoji(it.emoji, size: 64),
                            ),
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(8, 4, 8, 14),
                        child: Text(tr(context, it.key),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: nunito(17, weight: FontWeight.w800)),
                      ),
                    ],
                  ),
                  if (sel)
                    const Positioned(
                      top: 8,
                      right: 8,
                      child: SelectMark(selected: true, size: 26),
                    ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
