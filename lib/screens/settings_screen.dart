import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/app_config.dart';
import '../core/app_state.dart';
import '../core/sound.dart';
import '../core/strings.dart';
import '../core/theme.dart';
import '../widgets/common.dart';
import 'language_screen.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    return Scaffold(
      backgroundColor: AppColors.settingsBg,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
              child: Row(
                children: [
                  const BackCircle(),
                  Expanded(
                    child: Center(
                      heightFactor: 1,
                      child: OutlinedText(tr(context, 'setting'),
                          size: 32,
                          fill: AppColors.titleBlue,
                          stroke: Colors.white,
                          strokeWidth: 6),
                    ),
                  ),
                  const SizedBox(width: 38),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 24),
                children: [
                  _Group(children: [
                    _SwitchRow(
                      icon: Icons.forum_rounded,
                      color: const Color(0xFF2F86EE),
                      label: tr(context, 'turnOffMessages'),
                      value: s.messagesOff,
                      onChanged: s.setMessagesOff,
                    ),
                    _SwitchRow(
                      icon: Icons.music_note_rounded,
                      color: const Color(0xFF4A90E2),
                      label: tr(context, 'music'),
                      value: s.music,
                      onChanged: s.setMusic,
                    ),
                    _SwitchRow(
                      icon: Icons.graphic_eq_rounded,
                      color: const Color(0xFFA06CF0),
                      label: tr(context, 'soundFx'),
                      value: s.soundFx,
                      onChanged: s.setSoundFx,
                    ),
                    _SwitchRow(
                      icon: Icons.vibration_rounded,
                      color: const Color(0xFFF08A24),
                      label: tr(context, 'vibrate'),
                      value: s.vibrate,
                      onChanged: s.setVibrate,
                    ),
                  ]),
                  const SizedBox(height: 16),
                  _Group(children: [
                    _NavRow(
                      icon: Icons.translate_rounded,
                      color: const Color(0xFF5B6CF0),
                      label: tr(context, 'language'),
                      onTap: () => Navigator.of(context)
                          .push(fadeRoute(const LanguageScreen())),
                    ),
                    _NavRow(
                      icon: Icons.reply_rounded,
                      flipIcon: true,
                      color: const Color(0xFF2F86EE),
                      label: tr(context, 'share'),
                      onTap: () {
                        final box = context.findRenderObject() as RenderBox?;
                        Share.share(
                          tr(context, 'shareText',
                              {'url': AppConfig.playStoreUrl}),
                          sharePositionOrigin: box == null
                              ? null
                              : box.localToGlobal(Offset.zero) & box.size,
                        );
                      },
                    ),
                    _NavRow(
                      icon: Icons.star_rounded,
                      color: const Color(0xFFFFB300),
                      label: tr(context, 'rate'),
                      onTap: () => showRateSheet(context),
                    ),
                    _NavRow(
                      icon: Icons.chat_rounded,
                      color: const Color(0xFFB45CF0),
                      label: tr(context, 'feedback'),
                      onTap: () => sendFeedback(context),
                    ),
                    _NavRow(
                      icon: Icons.shield_rounded,
                      color: const Color(0xFFF0443A),
                      label: tr(context, 'policy'),
                      onTap: () =>
                          _open(context, Uri.parse(AppConfig.privacyPolicyUrl)),
                    ),
                    _NavRow(
                      icon: Icons.sync_rounded,
                      color: const Color(0xFF2EC27E),
                      label: tr(context, 'checkUpdate'),
                      onTap: () => openStore(context),
                    ),
                  ]),
                  const SizedBox(height: 18),
                  Center(
                    child: Text(AppConfig.buildTag,
                        style: nunito(12,
                            weight: FontWeight.w600,
                            color: const Color(0xFFA7B0B8))),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ================================================================ actions
Future<bool> _launch(Uri uri) async {
  try {
    return await launchUrl(uri, mode: LaunchMode.externalApplication);
  } catch (_) {
    return false;
  }
}

Future<void> _open(BuildContext context, Uri uri) async {
  final ok = await _launch(uri);
  if (!ok && context.mounted) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(tr(context, 'cantOpen'))));
  }
}

Future<void> openStore(BuildContext context) async {
  final ok = await _launch(Uri.parse(AppConfig.marketUrl));
  if (!ok && context.mounted) {
    await _open(context, Uri.parse(AppConfig.playStoreUrl));
  }
}

Future<void> sendFeedback(BuildContext context) async {
  final subject = Uri.encodeComponent(tr(context, 'feedbackSubject'));
  await _open(context,
      Uri.parse('mailto:${AppConfig.feedbackEmail}?subject=$subject'));
}

/// "Do you like this application?" bottom sheet with 5 stars + Rate US.
void showRateSheet(BuildContext context) {
  showModalBottomSheet(
    context: context,
    backgroundColor: Colors.white,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(26))),
    builder: (ctx) => _RateSheet(parent: context),
  );
}

/// "Rate For Us" pop-up shown after a round (stars + Rate US, × to close).
Future<void> showRateForUsDialog(BuildContext context) {
  return showDialog(
    context: context,
    builder: (ctx) => _RateForUsDialog(parent: context),
  );
}

class _RateForUsDialog extends StatefulWidget {
  const _RateForUsDialog({required this.parent});
  final BuildContext parent;

  @override
  State<_RateForUsDialog> createState() => _RateForUsDialogState();
}

class _RateForUsDialogState extends State<_RateForUsDialog> {
  int _stars = 0;

  Future<void> _rate() async {
    if (_stars == 0) return;
    AppScope.read(context).tap();
    final stars = _stars;
    final parent = widget.parent;
    Navigator.pop(context);
    if (!parent.mounted) return;
    ScaffoldMessenger.of(parent)
        .showSnackBar(SnackBar(content: Text(tr(parent, 'thanksRating'))));
    if (stars >= 4) {
      await openStore(parent);
    } else {
      await sendFeedback(parent);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.white,
      insetPadding: const EdgeInsets.symmetric(horizontal: 40),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: Stack(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 28, 20, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Emoji('⭐', size: 22),
                    Emoji('⭐', size: 32),
                    Emoji('⭐', size: 22),
                  ],
                ),
                const Emoji('👍', size: 58),
                const SizedBox(height: 10),
                Text(tr(context, 'rateForUs'),
                    style: nunito(18, weight: FontWeight.w700)),
                const SizedBox(height: 6),
                Text(tr(context, 'rateForUsSub'),
                    textAlign: TextAlign.center,
                    style: nunito(14,
                        weight: FontWeight.w500, color: AppColors.sub)),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(5, (i) {
                    final on = i < _stars;
                    return GestureDetector(
                      onTap: () {
                        AppScope.read(context).tap();
                        setState(() => _stars = i + 1);
                      },
                      child: AnimatedScale(
                        scale: on ? 1.08 : 1,
                        duration: const Duration(milliseconds: 150),
                        child: Icon(Icons.star_rounded,
                            size: 44,
                            color: on
                                ? const Color(0xFFFFC800)
                                : const Color(0xFFE0E3E7)),
                      ),
                    );
                  }),
                ),
                const SizedBox(height: 16),
                GestureDetector(
                  onTap: _rate,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    height: 50,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: _stars == 0
                          ? const Color(0xFFEDEFF2)
                          : const Color(0xFF1673FF),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(tr(context, 'rateUs'),
                        style: nunito(17,
                            weight: FontWeight.w700,
                            color: Colors.white)),
                  ),
                ),
              ],
            ),
          ),
          Positioned(
            right: 4,
            top: 4,
            child: IconButton(
              onPressed: () => Navigator.pop(context),
              icon: const Icon(Icons.close_rounded, color: Color(0xFF9A9A9A)),
            ),
          ),
        ],
      ),
    );
  }
}

class _RateSheet extends StatefulWidget {
  const _RateSheet({required this.parent});
  final BuildContext parent;

  @override
  State<_RateSheet> createState() => _RateSheetState();
}

class _RateSheetState extends State<_RateSheet> {
  int _stars = 5;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 26, 24, 22),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(tr(context, 'rateTitle'),
                textAlign: TextAlign.center,
                style: nunito(22, weight: FontWeight.w800)),
            const SizedBox(height: 6),
            Text(tr(context, 'rateSub'),
                textAlign: TextAlign.center,
                style: nunito(16,
                    weight: FontWeight.w500, color: AppColors.sub)),
            const SizedBox(height: 22),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: List.generate(5, (i) {
                final on = i < _stars;
                return GestureDetector(
                  onTap: () {
                    AppScope.read(context).tap();
                    setState(() => _stars = i + 1);
                  },
                  child: AnimatedScale(
                    scale: on ? 1 : 0.85,
                    duration: const Duration(milliseconds: 150),
                    child: Icon(Icons.star_rounded,
                        size: 62,
                        color: on
                            ? const Color(0xFFFFC800)
                            : const Color(0xFFDADDE1)),
                  ),
                );
              }),
            ),
            const SizedBox(height: 18),
            GestureDetector(
              onTap: () async {
                AppScope.read(context).tap();
                final stars = _stars;
                final parent = widget.parent;
                Navigator.pop(context);
                if (!parent.mounted) return;
                ScaffoldMessenger.of(parent).showSnackBar(
                    SnackBar(content: Text(tr(parent, 'thanksRating'))));
                if (stars >= 4) {
                  await openStore(parent);
                } else {
                  await sendFeedback(parent);
                }
              },
              child: Container(
                height: 62,
                decoration: BoxDecoration(
                  color: AppColors.rateGreenDark,
                  borderRadius: BorderRadius.circular(10),
                ),
                padding: const EdgeInsets.only(bottom: 5),
                child: Container(
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(10),
                    gradient: const LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [AppColors.rateGreenA, AppColors.rateGreenB],
                    ),
                  ),
                  child: OutlinedText(tr(context, 'rateUs'),
                      size: 26,
                      stroke: const Color(0xFF0E5E06),
                      strokeWidth: 5),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ================================================================ rows
class _Group extends StatelessWidget {
  const _Group({required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
              color: const Color(0xFF7FB8D6).withOpacity(0.18),
              blurRadius: 10,
              offset: const Offset(0, 3)),
        ],
      ),
      child: Column(children: children),
    );
  }
}

class _SwitchRow extends StatelessWidget {
  const _SwitchRow({
    required this.icon,
    required this.color,
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final IconData icon;
  final Color color;
  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () {
        AppScope.read(context).tap(Sfx.toggle);
        onChanged(!value);
      },
      child: SizedBox(
        height: 58,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              Icon(icon, color: color, size: 28),
              const SizedBox(width: 16),
              Expanded(
                  child: Text(label,
                      style: nunito(17,
                          weight: FontWeight.w600,
                          color: AppColors.textSoft))),
              Switch(
                value: value,
                onChanged: (v) {
                  AppScope.read(context).tap(Sfx.toggle);
                  onChanged(v);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavRow extends StatelessWidget {
  const _NavRow({
    required this.icon,
    required this.color,
    required this.label,
    required this.onTap,
    this.flipIcon = false,
  });

  final IconData icon;
  final Color color;
  final String label;
  final VoidCallback onTap;
  final bool flipIcon;

  @override
  Widget build(BuildContext context) {
    Widget ic = Icon(icon, color: color, size: 28);
    if (flipIcon) {
      ic = Transform.flip(flipX: true, child: ic);
    }
    return InkWell(
      onTap: () {
        AppScope.read(context).tap();
        onTap();
      },
      child: SizedBox(
        height: 58,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              ic,
              const SizedBox(width: 16),
              Expanded(
                  child: Text(label,
                      style: nunito(17,
                          weight: FontWeight.w600,
                          color: AppColors.textSoft))),
              const Icon(Icons.chevron_right_rounded,
                  color: AppColors.textSoft, size: 28),
            ],
          ),
        ),
      ),
    );
  }
}
