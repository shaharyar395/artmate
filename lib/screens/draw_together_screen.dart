import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../core/app_state.dart';
import '../core/dt_catalog.dart';
import '../core/strings.dart';
import '../core/theme.dart';
import '../widgets/common.dart';
import 'dt/dt_game_screen.dart';
import 'dt/dt_lobby_screen.dart';
import 'dt/dt_start.dart';
import 'dt/join_room_screen.dart';

/// Draw Together, same layout as the reference app: category chips at the
/// top (Popular, Cartoon, Anime, World Cup, Seasonal, Animal, Food, K-Pop,
/// Plant), a grid of 2-player pictures, and two floating buttons at the
/// bottom: Random Match and Join Room.
class DrawTogetherScreen extends StatefulWidget {
  const DrawTogetherScreen({super.key});

  /// "Draw Again" on a result page: reopen the pop-up for this picture.
  static final ValueNotifier<DtTemplate?> replay = ValueNotifier(null);

  @override
  State<DrawTogetherScreen> createState() => _DrawTogetherScreenState();
}

class _DrawTogetherScreenState extends State<DrawTogetherScreen> {
  void _onReplay() {
    final t = DrawTogetherScreen.replay.value;
    if (t == null || !mounted) return;
    DrawTogetherScreen.replay.value = null;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      // Back on this page, then the Quick Match / Invite Friend pop-up.
      final route = ModalRoute.of(context);
      Navigator.of(context).popUntil((r) => r == route);
      _play(t);
    });
  }

  String _category = 'popular';
  final ScrollController _grid = ScrollController();
  final ScrollController _chips = ScrollController();
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    DrawTogetherScreen.replay.value = null; // nothing left from before
    DrawTogetherScreen.replay.addListener(_onReplay);
    // Short skeleton while the pictures "load", like the reference app.
    Future.delayed(const Duration(milliseconds: 700), () {
      if (mounted) setState(() => _loading = false);
    });
  }

  @override
  void dispose() {
    DrawTogetherScreen.replay.removeListener(_onReplay);
    _grid.dispose();
    _chips.dispose();
    super.dispose();
  }

  /// Card pop-up: Quick Match (find a buddy for this picture) or Invite
  /// Friend (Lobby with a room code).
  Future<void> _play(DtTemplate t) async {
    final mode = await showDtStartDialog(context, t);
    if (mode == null || !mounted) return;
    Navigator.of(context).push(fadeRoute(mode == DtStartMode.quick
        ? DtGameScreen(template: t)
        : DtLobbyScreen(template: t)));
  }

  /// Random Match: a random picture, matched with whoever is online.
  void _randomMatch() {
    final t = kDtTemplates[math.Random().nextInt(kDtTemplates.length)];
    Navigator.of(context)
        .push(fadeRoute(DtGameScreen(template: t, quick: true)));
  }

  void _joinRoom() {
    Navigator.of(context).push(slideRoute(const JoinRoomScreen()));
  }

  void _selectCategory(String id, GlobalKey chipKey) {
    if (id == _category) return;
    setState(() => _category = id);
    if (_grid.hasClients) _grid.jumpTo(0);
    // Keep the selected chip in view.
    final ctx = chipKey.currentContext;
    if (ctx != null) {
      Scrollable.ensureVisible(ctx,
          alignment: 0.5,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut);
    }
  }

  @override
  Widget build(BuildContext context) {
    AppScope.of(context); // rebuild on language change
    final items = dtTemplatesFor(_category);
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            // ------------------------------------------------ title
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 8),
              child: Row(
                children: [
                  const BackCircle(),
                  Expanded(
                    child: Center(
                      heightFactor: 1,
                      child: OutlinedText(tr(context, 'drawTogether'),
                          size: 30,
                          fill: AppColors.titleBlue,
                          stroke: Colors.white,
                          strokeWidth: 5),
                    ),
                  ),
                  const SizedBox(width: 38),
                ],
              ),
            ),
            // ------------------------------------------------ chips
            SizedBox(
              height: 50,
              child: _loading
                  ? const _ChipSkeleton()
                  : _CategoryChips(
                      controller: _chips,
                      selected: _category,
                      onSelected: _selectCategory,
                    ),
            ),
            // ------------------------------------------------ grid + buttons
            Expanded(
              child: Stack(
                children: [
                  Positioned.fill(
                    child: _loading
                        ? const _GridSkeleton()
                        : GridView.builder(
                            controller: _grid,
                            padding:
                                const EdgeInsets.fromLTRB(18, 8, 18, 110),
                            gridDelegate:
                                const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 2,
                              mainAxisSpacing: 20,
                              crossAxisSpacing: 20,
                              childAspectRatio: 1,
                            ),
                            itemCount: items.length,
                            itemBuilder: (context, i) => _TemplateTile(
                              template: items[i],
                              onTap: () => _play(items[i]),
                            ),
                          ),
                  ),
                  Positioned(
                    left: 16,
                    right: 16,
                    bottom: 16 + MediaQuery.of(context).padding.bottom,
                    child: Row(
                      children: [
                        Expanded(
                          flex: 3,
                          child: _PillButton(
                            color: const Color(0xFF1677FF),
                            shadow: const Color(0xFF0B5AD1),
                            icon: Icons.casino_rounded,
                            label: tr(context, 'randomMatch'),
                            onTap: _randomMatch,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          flex: 2,
                          child: _PillButton(
                            color: const Color(0xFF22C55E),
                            shadow: const Color(0xFF179A47),
                            icon: Icons.login_rounded,
                            label: tr(context, 'joinRoom'),
                            onTap: _joinRoom,
                          ),
                        ),
                      ],
                    ),
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

// ================================================================ widgets
class _PillButton extends StatelessWidget {
  const _PillButton({
    required this.color,
    required this.shadow,
    required this.icon,
    required this.label,
    required this.onTap,
  });
  final Color color;
  final Color shadow;
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: onTap,
      child: Container(
        height: 50,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(25),
          boxShadow: [
            BoxShadow(color: shadow, offset: const Offset(0, 3)),
            const BoxShadow(
                color: Color(0x33000000), blurRadius: 10, offset: Offset(0, 5)),
          ],
        ),
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: Colors.white, size: 20),
            const SizedBox(width: 8),
            Flexible(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(label,
                    style: nunito(16,
                        weight: FontWeight.w800, color: Colors.white)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CategoryChips extends StatefulWidget {
  const _CategoryChips({
    required this.controller,
    required this.selected,
    required this.onSelected,
  });
  final ScrollController controller;
  final String selected;
  final void Function(String id, GlobalKey key) onSelected;

  @override
  State<_CategoryChips> createState() => _CategoryChipsState();
}

class _CategoryChipsState extends State<_CategoryChips> {
  final Map<String, GlobalKey> _keys = {
    for (final c in kDtCategories) c.id: GlobalKey(),
  };

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      controller: widget.controller,
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.fromLTRB(14, 6, 14, 8),
      itemCount: kDtCategories.length,
      separatorBuilder: (_, __) => const SizedBox(width: 10),
      itemBuilder: (context, i) {
        final c = kDtCategories[i];
        final sel = c.id == widget.selected;
        return GestureDetector(
          key: _keys[c.id],
          onTap: () {
            AppScope.read(context).tap();
            widget.onSelected(c.id, _keys[c.id]!);
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            padding: const EdgeInsets.symmetric(horizontal: 14),
            decoration: BoxDecoration(
              gradient: sel
                  ? const LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Color(0xFFC4E1FF), Color(0xFFA3CDFB)],
                    )
                  : null,
              color: sel ? null : Colors.white,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                  color: sel ? const Color(0xFFA3CDFB) : const Color(0xFFE3E6EA),
                  width: 1.3),
            ),
            alignment: Alignment.center,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (c.emoji != null) ...[
                  Emoji(c.emoji!, size: 18),
                  const SizedBox(width: 4),
                ] else if (sel) ...[
                  const Icon(Icons.auto_awesome_rounded,
                      size: 16, color: Colors.white),
                  const SizedBox(width: 4),
                ],
                Text(tr(context, c.key),
                    style: nunito(14,
                        weight: FontWeight.w700,
                        color: sel ? Colors.white : AppColors.selectBlue)),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _TemplateTile extends StatelessWidget {
  const _TemplateTile({required this.template, required this.onTap});
  final DtTemplate template;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFEDEFF2), width: 1.2),
          boxShadow: const [
            BoxShadow(
                color: Color(0x248FA3B8), offset: Offset(0, 4), blurRadius: 8),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(13),
          child: Stack(
            children: [
              Positioned.fill(
                child: Padding(
                  padding: const EdgeInsets.all(10),
                  child: ArtSlot(
                    asset: 'tpl_${template.id}.png',
                    fallback: DtTemplatePicture(template: template),
                  ),
                ),
              ),
              Positioned(
                top: 8,
                right: 8,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: const Color(0xFFDDEBFF),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.group_rounded,
                          size: 13, color: Color(0xFF3A8EF0)),
                      const SizedBox(width: 3),
                      Text('2',
                          style: nunito(12,
                              weight: FontWeight.w800,
                              color: const Color(0xFF3A8EF0))),
                    ],
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

class _ChipSkeleton extends StatelessWidget {
  const _ChipSkeleton();

  @override
  Widget build(BuildContext context) {
    return ListView(
      scrollDirection: Axis.horizontal,
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(14, 6, 14, 8),
      children: [
        for (final w in [70.0, 56.0, 56.0, 56.0, 56.0])
          Container(
            width: w,
            margin: const EdgeInsets.only(right: 10),
            decoration: BoxDecoration(
              color: const Color(0xFFF0F2F4),
              borderRadius: BorderRadius.circular(10),
            ),
          ),
      ],
    );
  }
}

class _GridSkeleton extends StatelessWidget {
  const _GridSkeleton();

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(18, 8, 18, 110),
      crossAxisCount: 2,
      mainAxisSpacing: 20,
      crossAxisSpacing: 20,
      children: [
        for (var i = 0; i < 6; i++)
          Container(
            decoration: BoxDecoration(
              color: const Color(0xFFF0F2F4),
              borderRadius: BorderRadius.circular(14),
            ),
          ),
      ],
    );
  }
}
