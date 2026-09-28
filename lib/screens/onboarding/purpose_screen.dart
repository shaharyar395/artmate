import 'package:flutter/material.dart';

import '../../core/app_state.dart';
import '../../core/catalog.dart';
import '../../core/strings.dart';
import '../../core/theme.dart';
import '../../widgets/common.dart';
import 'interests_screen.dart';

/// Onboarding step 2: "So, what brings you in today?"
class PurposeScreen extends StatefulWidget {
  const PurposeScreen({super.key});

  @override
  State<PurposeScreen> createState() => _PurposeScreenState();
}

class _PurposeScreenState extends State<PurposeScreen> {
  int? _selected;

  @override
  Widget build(BuildContext context) {
    return OnboardingScaffold(
      step: 2,
      title: tr(context, 'purposeTitle'),
      subtitle: tr(context, 'purposeSub'),
      canContinue: _selected != null,
      onContinue: () {
        AppScope.read(context).setPurpose(_selected!);
        Navigator.of(context).push(fadeRoute(const InterestsScreen()));
      },
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
        itemCount: kPurposes.length,
        separatorBuilder: (_, __) => const SizedBox(height: 14),
        itemBuilder: (context, i) {
          final p = kPurposes[i];
          final sel = _selected == i;
          return Pressable(
            onTap: () => setState(() => _selected = i),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              height: 82,
              padding: const EdgeInsets.symmetric(horizontal: 14),
              decoration: BoxDecoration(
                color: sel ? AppColors.selectBg : Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                    color: sel ? AppColors.selectBlue : AppColors.border,
                    width: sel ? 2.5 : 1.5),
              ),
              child: Row(
                children: [
                  SizedBox(
                    width: 62,
                    height: 62,
                    child: ArtSlot(
                      asset: p.asset,
                      fallback: Center(child: Emoji(p.emoji, size: 38)),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Text(tr(context, p.key),
                        style: nunito(18,
                            weight: FontWeight.w700,
                            color: AppColors.textSoft)),
                  ),
                  const SizedBox(width: 8),
                  SelectMark(selected: sel),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
