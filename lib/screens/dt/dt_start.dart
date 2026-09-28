import 'package:flutter/material.dart';

import '../../core/app_state.dart';
import '../../core/catalog.dart';
import '../../core/dt_catalog.dart';
import '../../core/strings.dart';
import '../../core/theme.dart';
import '../../core/trace_steps.dart';
import '../../widgets/common.dart';
import 'dt_game_screen.dart' show DtTemplatePicture;

/// What the player picked on the card pop-up.
enum DtStartMode { quick, invite }

/// Short name shown under a picture (like the reference app's "data_369").
String dtTemplateName(DtTemplate t) => t.id.replaceFirst('dt_', '');

final Map<String, int> _stepCache = {};

/// Total colouring steps of both drawings ("26 steps").
int dtTotalSteps(DtTemplate t) => _stepCache.putIfAbsent(
    t.id,
    () =>
        buildColourSteps(t.artFor(0)).length +
        buildColourSteps(t.artFor(1)).length);

/// Card pop-up: picture, Quick Match / Invite Friend, Continue / Create Lobby.
/// Tap outside or × to close.
Future<DtStartMode?> showDtStartDialog(BuildContext context, DtTemplate t) {
  return showGeneralDialog<DtStartMode>(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'start',
    barrierColor: Colors.black.withOpacity(0.5),
    transitionDuration: const Duration(milliseconds: 220),
    transitionBuilder: (_, a, __, child) => ScaleTransition(
      scale: Tween(begin: 0.9, end: 1.0)
          .animate(CurvedAnimation(parent: a, curve: Curves.easeOutBack)),
      child: FadeTransition(opacity: a, child: child),
    ),
    pageBuilder: (ctx, _, __) => _StartDialog(template: t),
  );
}

class _StartDialog extends StatefulWidget {
  const _StartDialog({required this.template});
  final DtTemplate template;

  @override
  State<_StartDialog> createState() => _StartDialogState();
}

class _StartDialogState extends State<_StartDialog> {
  DtStartMode _mode = DtStartMode.quick;

  Widget _option(DtStartMode m, IconData icon, String label, Color color) {
    final sel = _mode == m;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          AppScope.read(context).tap();
          setState(() => _mode = m);
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          height: 104,
          decoration: BoxDecoration(
            color: sel ? Colors.white : const Color(0xFFF3F4F6),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
                color: sel ? color : const Color(0xFFF3F4F6), width: 2),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon,
                  size: 34, color: sel ? color : const Color(0xFF5B5F66)),
              const SizedBox(height: 8),
              Text(label,
                  style: nunito(13,
                      weight: FontWeight.w700,
                      color: sel ? color : const Color(0xFF5B5F66))),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = widget.template;
    const blue = Color(0xFF1677FF);
    const orange = Color(0xFFF5A623);
    return Center(
      child: Material(
        color: Colors.transparent,
        child: SizedBox(
          width: 320,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                margin: const EdgeInsets.only(top: 60),
                padding: const EdgeInsets.fromLTRB(16, 104, 16, 18),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(dtTemplateName(t),
                            style: nunito(15,
                                weight: FontWeight.w700,
                                color: const Color(0xFF3A3A3A))),
                        const SizedBox(width: 8),
                        const PlayersBadge(),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        _option(DtStartMode.quick, Icons.bolt_rounded,
                            tr(context, 'quickMatch'), blue),
                        const SizedBox(width: 12),
                        _option(DtStartMode.invite,
                            Icons.person_add_alt_1_rounded,
                            tr(context, 'inviteFriendBtn'), orange),
                      ],
                    ),
                    const SizedBox(height: 16),
                    BlueButton(
                      label: tr(
                          context,
                          _mode == DtStartMode.quick
                              ? 'continue'
                              : 'createLobby'),
                      onTap: () => Navigator.pop(context, _mode),
                    ),
                  ],
                ),
              ),
              // Picture card overlapping the top edge.
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: Center(
                  child: Container(
                    width: 150,
                    height: 150,
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: const [
                        BoxShadow(
                            color: Color(0x33000000),
                            blurRadius: 10,
                            offset: Offset(0, 3)),
                      ],
                    ),
                    child: ArtSlot(
                      asset: 'tpl_${t.id}.png',
                      fallback: DtTemplatePicture(template: t),
                    ),
                  ),
                ),
              ),
              Positioned(
                top: 20,
                right: 12,
                child: GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: Container(
                    width: 30,
                    height: 30,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      border: Border.all(color: const Color(0xFFE2E4E8)),
                    ),
                    child: const Icon(Icons.close_rounded,
                        size: 18, color: Color(0xFF6B6B6B)),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Small light-blue "👥 2" badge.
class PlayersBadge extends StatelessWidget {
  const PlayersBadge({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: const Color(0xFFDDEBFF),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.group_rounded, size: 13, color: Color(0xFF3A8EF0)),
          const SizedBox(width: 3),
          Text('2',
              style: nunito(12,
                  weight: FontWeight.w800, color: const Color(0xFF3A8EF0))),
        ],
      ),
    );
  }
}

/// Wide blue button with a darker bottom edge.
class BlueButton extends StatelessWidget {
  const BlueButton(
      {super.key, required this.label, required this.onTap, this.height = 50});
  final String label;
  final VoidCallback onTap;
  final double height;

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: onTap,
      child: Container(
        height: height,
        width: double.infinity,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: const Color(0xFF1677FF),
          borderRadius: BorderRadius.circular(10),
          boxShadow: const [
            BoxShadow(color: Color(0xFF0B56C7), offset: Offset(0, 3)),
          ],
        ),
        child: Text(label,
            style: nunito(16, weight: FontWeight.w800, color: Colors.white)),
      ),
    );
  }
}

/// "Change" chip.
class ChangeChip extends StatelessWidget {
  const ChangeChip({super.key, required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: const Color(0xFFEAF3FF),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.refresh_rounded,
                size: 16, color: Color(0xFF1677FF)),
            const SizedBox(width: 4),
            Text(tr(context, 'change'),
                style: nunito(13,
                    weight: FontWeight.w800, color: const Color(0xFF1677FF))),
          ],
        ),
      ),
    );
  }
}

/// Round avatar with a coloured ring; [host] adds a little crown.
class RingAvatar extends StatelessWidget {
  const RingAvatar({
    super.key,
    required this.avatar,
    this.size = 64,
    this.host = false,
    this.ring = const Color(0xFF3A8EF0),
    this.check = false,
  });
  final int? avatar; // null = empty slot
  final double size;
  final bool host;
  final Color ring;
  final bool check;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size + 6,
      height: size + 6,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            width: size,
            height: size,
            margin: const EdgeInsets.all(3),
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              border: Border.all(color: ring, width: 2.5),
            ),
            alignment: Alignment.center,
            child: avatar == null
                ? null
                : Emoji(kAvatars[avatar! % kAvatars.length], size: size * 0.62),
          ),
          if (host)
            const Positioned(
                right: 2, top: -4, child: Emoji('👑', size: 16)),
          if (check)
            const Positioned(
              right: 0,
              bottom: 0,
              child: Icon(Icons.check_circle_rounded,
                  color: AppColors.switchGreen, size: 20),
            ),
        ],
      ),
    );
  }
}

/// "Choose a picture" sheet used by the Change buttons.
Future<DtTemplate?> showDtTemplatePicker(
    BuildContext context, DtTemplate current) {
  return showModalBottomSheet<DtTemplate>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22))),
    builder: (ctx) => SizedBox(
      height: MediaQuery.of(ctx).size.height * 0.72,
      child: Column(
        children: [
          const SizedBox(height: 10),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: const Color(0xFFDDDDDD),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 12),
          Text(tr(ctx, 'choosePicture'),
              style: nunito(18, weight: FontWeight.w800)),
          const SizedBox(height: 8),
          Expanded(
            child: GridView.builder(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
              ),
              itemCount: kDtTemplates.length,
              itemBuilder: (_, i) {
                final t = kDtTemplates[i];
                final sel = t.id == current.id;
                return GestureDetector(
                  onTap: () => Navigator.pop(ctx, t),
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                          color: sel
                              ? const Color(0xFF1677FF)
                              : const Color(0xFFEDEFF2),
                          width: sel ? 2 : 1.2),
                    ),
                    child: ArtSlot(
                      asset: 'tpl_${t.id}.png',
                      fallback: DtTemplatePicture(template: t),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    ),
  );
}
