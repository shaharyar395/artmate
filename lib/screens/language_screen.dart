import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/app_state.dart';
import '../core/strings.dart';
import '../core/theme.dart';
import '../widgets/common.dart';

/// Settings > Language (blue game-style screen; apply with the green check).
class LanguageScreen extends StatefulWidget {
  const LanguageScreen({super.key});

  @override
  State<LanguageScreen> createState() => _LanguageScreenState();
}

class _LanguageScreenState extends State<LanguageScreen> {
  late String _selected = AppScope.read(context).lang;

  Widget _squareButton(
      {required Color color, required IconData icon, required VoidCallback onTap}) {
    return Pressable(
      onTap: onTap,
      child: Container(
        width: 46,
        height: 46,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.white, width: 2.5),
          boxShadow: const [
            BoxShadow(color: Color(0x33000000), offset: Offset(0, 3)),
          ],
        ),
        child: Icon(icon, color: Colors.white, size: 30),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        body: BrushBackground(
          base: AppColors.langScreenBlue,
          dark: true,
          child: SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 10, 16, 14),
                  child: Row(
                    children: [
                      _squareButton(
                        color: AppColors.pinkBtn,
                        icon: Icons.chevron_left_rounded,
                        onTap: () => Navigator.of(context).pop(),
                      ),
                      Expanded(
                        child: Center(
                          heightFactor: 1,
                          child: OutlinedText(tr(context, 'language'),
                              size: 26,
                              stroke: const Color(0xFF1E6B12),
                              strokeWidth: 5),
                        ),
                      ),
                      _squareButton(
                        color: AppColors.greenBtn,
                        icon: Icons.check_rounded,
                        onTap: () {
                          AppScope.read(context).setLang(_selected);
                          Navigator.of(context).pop();
                        },
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: ListView.separated(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                    itemCount: kSettingsLangOrder.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 14),
                    itemBuilder: (context, i) {
                      final l = langByCode(kSettingsLangOrder[i]);
                      final sel = l.code == _selected;
                      return Pressable(
                        onTap: () => setState(() => _selected = l.code),
                        child: Container(
                          height: 56,
                          padding: const EdgeInsets.symmetric(horizontal: 14),
                          decoration: BoxDecoration(
                            color: sel ? null : Colors.white,
                            gradient: sel
                                ? const LinearGradient(colors: [
                                    AppColors.langSelectedA,
                                    AppColors.langSelectedB
                                  ])
                                : null,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                                color: sel
                                    ? const Color(0xFFFFF1B0)
                                    : const Color(0xFFD9E6F2),
                                width: 2),
                            boxShadow: const [
                              BoxShadow(
                                  color: Color(0x33003A80),
                                  offset: Offset(0, 3)),
                            ],
                          ),
                          child: Row(
                            children: [
                              FlagBox(l.flag, width: 36, height: 26),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(l.english,
                                    style: nunito(21,
                                        weight: FontWeight.w700,
                                        color: AppColors.text)),
                              ),
                              Container(
                                width: 22,
                                height: 22,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                      color: sel
                                          ? Colors.white
                                          : const Color(0xFF5A5A5A),
                                      width: 2),
                                ),
                                alignment: Alignment.center,
                                child: sel
                                    ? Container(
                                        width: 10,
                                        height: 10,
                                        decoration: const BoxDecoration(
                                            color: Colors.white,
                                            shape: BoxShape.circle),
                                      )
                                    : null,
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
