import 'package:flutter/material.dart';

import '../../core/app_state.dart';
import '../../core/strings.dart';
import '../../core/theme.dart';
import '../../widgets/common.dart';
import 'age_screen.dart';

/// Onboarding step 0: "Choose your language".
class LanguageSelectScreen extends StatefulWidget {
  const LanguageSelectScreen({super.key});

  @override
  State<LanguageSelectScreen> createState() => _LanguageSelectScreenState();
}

class _LanguageSelectScreenState extends State<LanguageSelectScreen> {
  late String _selected = AppScope.read(context).lang;

  @override
  Widget build(BuildContext context) {
    return OnboardingScaffold(
      title: tr(context, 'chooseLanguage'),
      subtitle: tr(context, 'changeAnytime'),
      canContinue: true,
      onContinue: () {
        AppScope.read(context).setLang(_selected);
        Navigator.of(context).push(fadeRoute(const AgeScreen()));
      },
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
        itemCount: kLanguages.length,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (context, i) {
          final l = kLanguages[i];
          final sel = l.code == _selected;
          return Pressable(
            onTap: () => setState(() => _selected = l.code),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              height: 74,
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
                  FlagBox(l.flag),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(l.native, style: nunito(18, weight: FontWeight.w800)),
                        Text(l.english,
                            style: nunito(14,
                                weight: FontWeight.w500,
                                color: AppColors.sub)),
                      ],
                    ),
                  ),
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
