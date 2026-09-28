import 'package:flutter/material.dart';

import '../../core/app_state.dart';
import '../../core/catalog.dart';
import '../../core/strings.dart';
import '../../core/theme.dart';
import '../../widgets/common.dart';
import 'purpose_screen.dart';

/// Onboarding step 1: "Let us know your age".
class AgeScreen extends StatefulWidget {
  const AgeScreen({super.key});

  @override
  State<AgeScreen> createState() => _AgeScreenState();
}

class _AgeScreenState extends State<AgeScreen> {
  int? _selected;

  @override
  Widget build(BuildContext context) {
    return OnboardingScaffold(
      step: 1,
      title: tr(context, 'ageTitle'),
      subtitle: tr(context, 'ageSub'),
      canContinue: _selected != null,
      onContinue: () {
        AppScope.read(context).setAge(_selected!);
        Navigator.of(context).push(fadeRoute(const PurposeScreen()));
      },
      child: GridView.builder(
        padding: const EdgeInsets.fromLTRB(28, 10, 28, 8),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          mainAxisSpacing: 18,
          crossAxisSpacing: 18,
          childAspectRatio: 0.9,
        ),
        itemCount: kAges.length,
        itemBuilder: (context, i) {
          final a = kAges[i];
          final sel = _selected == i;
          return Pressable(
            onTap: () => setState(() => _selected = i),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                    color: sel ? AppColors.selectBlue : Colors.transparent,
                    width: 3),
                boxShadow: [
                  BoxShadow(
                      color: Colors.black.withOpacity(0.07),
                      blurRadius: 10,
                      offset: const Offset(0, 3)),
                ],
              ),
              alignment: Alignment.center,
              child: FractionallySizedBox(
                widthFactor: 0.66,
                child: AspectRatio(
                  aspectRatio: 1,
                  child: Container(
                    decoration:
                        BoxDecoration(color: a.circle, shape: BoxShape.circle),
                    alignment: Alignment.center,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        FittedBox(
                          child: Text(a.label,
                              style: nunito(27, weight: FontWeight.w800)),
                        ),
                        Text(tr(context, 'year'),
                            style: nunito(17,
                                weight: FontWeight.w500,
                                color: AppColors.sub)),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
