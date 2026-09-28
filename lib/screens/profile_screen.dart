import 'dart:io';

import 'package:flutter/material.dart';

import '../core/app_state.dart';
import '../core/catalog.dart';
import '../core/levels.dart';
import '../core/strings.dart';
import '../core/theme.dart';
import '../widgets/common.dart';
import 'buddies_screen.dart';
import 'levels_screen.dart';
import 'settings_screen.dart';
import 'trace_art_screen.dart';
import '../widgets/trace_item_art.dart';
import '../battle/battle_data.dart';
import '../core/trace_catalog.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  int _tab = 0; // 0 = My album, 1 = Favorite
  bool _newestFirst = true;

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [AppColors.profileTop, Color(0xFFE6F8FF), Colors.white],
            stops: [0, 0.45, 1],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // ---------------------------------------------- header
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
                child: Row(
                  children: [
                    const BackCircle(),
                    Expanded(
                      child: Center(
                        heightFactor: 1,
                        child: OutlinedText(tr(context, 'profile'),
                            size: 32,
                            fill: AppColors.titleBlue,
                            stroke: Colors.white,
                            strokeWidth: 6),
                      ),
                    ),
                    GestureDetector(
                      onTap: () {
                        s.tap();
                        Navigator.of(context)
                            .push(fadeRoute(const SettingsScreen()));
                      },
                      child: const Icon(Icons.settings_rounded,
                          size: 34, color: Color(0xFF7C93AE)),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 10, 16, 24),
                  children: [
                    // ------------------------------------ avatar + name
                    Center(
                      child: GestureDetector(
                        onTap: () => _pickAvatar(context),
                        child: SizedBox(
                          width: 104,
                          height: 104,
                          child: Stack(
                            children: [
                              Container(
                                width: 100,
                                height: 100,
                                decoration: const BoxDecoration(
                                    color: Colors.white,
                                    shape: BoxShape.circle),
                                alignment: Alignment.center,
                                child: Emoji(
                                    kAvatars[s.avatarIndex % kAvatars.length],
                                    size: 62),
                              ),
                              Positioned(
                                right: 2,
                                bottom: 6,
                                child: Container(
                                  width: 30,
                                  height: 30,
                                  decoration: BoxDecoration(
                                    color: AppColors.selectBlue,
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                        color: Colors.white, width: 2),
                                  ),
                                  child: const Icon(Icons.edit_rounded,
                                      color: Colors.white, size: 16),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Center(
                      child: GestureDetector(
                        onTap: () => _editName(context),
                        child: Text(s.username,
                            style: nunito(26,
                                weight: FontWeight.w600,
                                color: const Color(0xFF2B2B2B))),
                      ),
                    ),
                    const SizedBox(height: 16),
                    // ------------------------------------ stats card
                    _Card(
                      padding: const EdgeInsets.all(14),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: ValueListenableBuilder<int>(
                                  valueListenable: s.spentSeconds,
                                  builder: (_, v, __) => _StatTile(
                                    emoji: '⏱️',
                                    label: tr(context, 'spentTime'),
                                    value: formatDuration(v),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: _StatTile(
                                  emoji: '📕',
                                  label: tr(context, 'lesson'),
                                  value: '${s.lessons}',
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              Container(
                                width: 58,
                                height: 58,
                                decoration: const BoxDecoration(
                                    color: Color(0xFFE5F6FC),
                                    shape: BoxShape.circle),
                                alignment: Alignment.center,
                                child: const Emoji('🏅', size: 30),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  children: [
                                    Text(tr(context, 'yourLevel'),
                                        style: nunito(14,
                                            weight: FontWeight.w500,
                                            color: AppColors.textSoft)),
                                    Text(tr(context, levelNameKey(s.lessons)),
                                        style: nunito(17,
                                            weight: FontWeight.w800,
                                            color: AppColors.levelBlue)),
                                  ],
                                ),
                              ),
                              Pressable(
                                onTap: () => Navigator.of(context)
                                    .push(fadeRoute(const LevelsScreen())),
                                child: Container(
                                  width: 44,
                                  height: 44,
                                  decoration: BoxDecoration(
                                    color: AppColors.blue,
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: const Icon(
                                      Icons.chevron_right_rounded,
                                      color: Colors.white,
                                      size: 30),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                    // ------------------------------------ buddies
                    Pressable(
                      onTap: () => Navigator.of(context)
                          .push(slideRoute(const BuddiesScreen())),
                      child: _Card(
                        padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
                        child: Row(
                          children: [
                            const ArtSlot(
                              asset: 'buddies.png',
                              fallback: Emoji('👫', size: 36),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(tr(context, 'myBuddies'),
                                      style:
                                          nunito(17, weight: FontWeight.w800)),
                                  Text(
                                      tr(context, 'buddiesCount',
                                          {'n': '${s.buddies}'}),
                                      style: nunito(15,
                                          weight: FontWeight.w500,
                                          color: AppColors.sub)),
                                ],
                              ),
                            ),
                            const Icon(Icons.chevron_right_rounded,
                                color: AppColors.textSoft, size: 28),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),
                    // ------------------------------------ tabs + sort
                    Row(
                      children: [
                        _TabPill(
                          label: tr(context, 'myAlbum'),
                          selected: _tab == 0,
                          onTap: () => setState(() => _tab = 0),
                        ),
                        const SizedBox(width: 10),
                        _TabPill(
                          label: tr(context, 'favorite'),
                          selected: _tab == 1,
                          onTap: () => setState(() => _tab = 1),
                        ),
                        const Spacer(),
                        _SortButton(
                          newestFirst: _newestFirst,
                          onChanged: (v) => setState(() => _newestFirst = v),
                        ),
                      ],
                    ),
                    const SizedBox(height: 26),
                    // ------------------------------------ album / empty
                    if (_entries(s).isNotEmpty)
                      _AlbumGrid(entries: _entries(s))
                    else ...[
                    Center(
                      child: SizedBox(
                        width: 190,
                        height: 180,
                        child: ArtSlot(
                          asset: 'empty_album.png',
                          fallback: Stack(
                            alignment: Alignment.center,
                            children: const [
                              Positioned(
                                  top: 0, child: Emoji('🐶', size: 70)),
                              Positioned(
                                  bottom: 0, child: Emoji('📦', size: 110)),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),
                    Center(
                      child: Pressable(
                        onTap: () => Navigator.of(context)
                            .push(slideRoute(const TraceArtScreen())),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 22, vertical: 10),
                          decoration: BoxDecoration(
                            color: const Color(0xFF2E7FD9),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(tr(context, 'drawNow'),
                                  style: nunito(25,
                                      weight: FontWeight.w600,
                                      color: Colors.white)),
                              const SizedBox(width: 8),
                              const Icon(Icons.edit_rounded,
                                  color: Colors.white, size: 20),
                            ],
                          ),
                        ),
                      ),
                    ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  List<AlbumEntry> _entries(AppState s) {
    final list = s.album.where((e) => _tab == 0 || e.favorite).toList()
      ..sort((a, b) => _newestFirst
          ? b.createdAt.compareTo(a.createdAt)
          : a.createdAt.compareTo(b.createdAt));
    return list;
  }

  // ------------------------------------------------------------ dialogs
  void _pickAvatar(BuildContext context) {
    final s = AppScope.read(context);
    s.tap();
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(tr(context, 'chooseAvatar'),
                  style: nunito(20, weight: FontWeight.w800)),
              const SizedBox(height: 16),
              GridView.count(
                crossAxisCount: 4,
                shrinkWrap: true,
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                physics: const NeverScrollableScrollPhysics(),
                children: List.generate(kAvatars.length, (i) {
                  final sel = i == s.avatarIndex;
                  return GestureDetector(
                    onTap: () {
                      s.tap();
                      s.setAvatar(i);
                      Navigator.pop(ctx);
                    },
                    child: Container(
                      decoration: BoxDecoration(
                        color: const Color(0xFFEFF8FF),
                        shape: BoxShape.circle,
                        border: Border.all(
                            color: sel
                                ? AppColors.selectBlue
                                : Colors.transparent,
                            width: 3),
                      ),
                      alignment: Alignment.center,
                      child: Emoji(kAvatars[i], size: 38),
                    ),
                  );
                }),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _editName(BuildContext context) {
    final s = AppScope.read(context);
    s.tap();
    final ctrl = TextEditingController(text: s.username);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        title: Text(tr(context, 'editName'),
            style: nunito(20, weight: FontWeight.w800)),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          maxLength: 16,
          style: nunito(18, weight: FontWeight.w600),
          decoration: const InputDecoration(border: OutlineInputBorder()),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(tr(context, 'cancel'))),
          FilledButton(
            onPressed: () {
              final v = ctrl.text.trim();
              if (v.isNotEmpty) s.setUsername(v);
              Navigator.pop(ctx);
            },
            child: Text(tr(context, 'save')),
          ),
        ],
      ),
    );
  }

}

// ================================================================ widgets
class _Card extends StatelessWidget {
  const _Card({required this.child, required this.padding});
  final Widget child;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFDDEFFA), width: 1.5),
      ),
      child: child,
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile(
      {required this.emoji, required this.label, required this.value});
  final String emoji;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 64,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFF4F7FA),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Emoji(emoji, size: 32),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: nunito(13,
                        weight: FontWeight.w500, color: AppColors.textSoft)),
                Text(value, style: nunito(16, weight: FontWeight.w800)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TabPill extends StatelessWidget {
  const _TabPill(
      {required this.label, required this.selected, required this.onTap});
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        width: 128,
        height: 42,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? const Color(0xFF3B3B3B) : Colors.white,
          borderRadius: BorderRadius.circular(22),
        ),
        child: Text(label,
            style: nunito(16,
                weight: FontWeight.w600,
                color: selected ? Colors.white : AppColors.textSoft)),
      ),
    );
  }
}

class _SortButton extends StatelessWidget {
  const _SortButton({required this.newestFirst, required this.onChanged});
  final bool newestFirst;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<bool>(
      tooltip: '',
      color: Colors.white,
      elevation: 6,
      offset: const Offset(-10, 44),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      onOpened: () => AppScope.read(context).tap(),
      onSelected: onChanged,
      itemBuilder: (ctx) => [
        PopupMenuItem(
          value: true,
          height: 56,
          child: Center(
            child: Text(tr(context, 'sortNewest'),
                style: nunito(17,
                    weight: newestFirst ? FontWeight.w800 : FontWeight.w600)),
          ),
        ),
        PopupMenuItem(
          value: false,
          height: 56,
          child: Center(
            child: Text(tr(context, 'sortOldest'),
                style: nunito(17,
                    weight: !newestFirst ? FontWeight.w800 : FontWeight.w600)),
          ),
        ),
      ],
      child: Container(
        width: 38,
        height: 38,
        decoration: const BoxDecoration(
            color: Color(0xFFC4CBD3), shape: BoxShape.circle),
        child: const Icon(Icons.swap_vert_rounded,
            color: Colors.white, size: 26),
      ),
    );
  }
}

// ================================================================ album
class _AlbumGrid extends StatelessWidget {
  const _AlbumGrid({required this.entries});
  final List<AlbumEntry> entries;

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 14,
        crossAxisSpacing: 14,
      ),
      itemCount: entries.length,
      itemBuilder: (context, i) {
        final e = entries[i];
        return Pressable(
          onTap: () => _open(context, e),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: const [
                BoxShadow(color: Color(0xFFD5DEE6), offset: Offset(0, 4)),
              ],
            ),
            child: Stack(
              children: [
                Positioned.fill(
                  child: Padding(
                    padding: const EdgeInsets.all(8),
                    child: _AlbumDrawing(entry: e),
                  ),
                ),
                if (e.favorite)
                  const Positioned(
                    right: 8,
                    top: 6,
                    child: Icon(Icons.favorite_rounded,
                        color: Color(0xFFFF4D6D), size: 22),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _open(BuildContext context, AlbumEntry e) {
    showDialog(
      context: context,
      builder: (ctx) {
        final s = AppScope.of(ctx);
        final fav = s.album.any((x) => x.id == e.id && x.favorite);
        return Dialog(
          backgroundColor: Colors.white,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                    width: 260, height: 260, child: _AlbumDrawing(entry: e)),
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    IconButton(
                      iconSize: 32,
                      onPressed: () => s.toggleFavorite(e.id),
                      icon: Icon(
                          fav
                              ? Icons.favorite_rounded
                              : Icons.favorite_border_rounded,
                          color: const Color(0xFFFF4D6D)),
                    ),
                    IconButton(
                      iconSize: 32,
                      onPressed: () {
                        s.deleteFromAlbum(e.id);
                        Navigator.pop(ctx);
                      },
                      icon: const Icon(Icons.delete_outline_rounded,
                          color: Color(0xFF6B6B6B)),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _AlbumDrawing extends StatelessWidget {
  const _AlbumDrawing({required this.entry});
  final AlbumEntry entry;

  @override
  Widget build(BuildContext context) {
    final img = AppScope.of(context).albumImagePath(entry);
    if (img != null && File(img).existsSync()) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: Image.file(File(img), fit: BoxFit.contain),
      );
    }
    final strokes = [
      for (final raw in entry.strokes)
        if (BStroke.decode(raw) != null) BStroke.decode(raw)!
    ];
    final item = traceItemById(entry.itemId);
    return Stack(
      children: [
        Positioned(
          left: 0,
          bottom: 0,
          child: Opacity(
              opacity: 0.9,
              child: SizedBox(
                  width: 22, height: 22, child: TraceItemArt(item: item, size: 18))),
        ),
        Positioned.fill(
          child: CustomPaint(painter: _AlbumPainter(strokes)),
        ),
      ],
    );
  }
}

class _AlbumPainter extends CustomPainter {
  _AlbumPainter(this.strokes);
  final List<BStroke> strokes;

  @override
  void paint(Canvas canvas, Size size) =>
      paintStrokes(canvas, size.shortestSide, strokes, widthScale: 1.2);

  @override
  bool shouldRepaint(covariant _AlbumPainter old) => true;
}
