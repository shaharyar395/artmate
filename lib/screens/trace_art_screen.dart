import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/app_state.dart';
import '../core/strings.dart';
import '../core/theme.dart';
import '../core/trace_catalog.dart';
import '../widgets/common.dart';
import '../widgets/trace_item_art.dart';
import 'trace_preview_screen.dart';

const Color _pageBg = Color(0xFFEEFAFE);
const Color _pinnedBar = Color(0xFF5AE4FA);

/// Trace Art: auto-playing carousel, category chips, grid of pictures.
class TraceArtScreen extends StatefulWidget {
  const TraceArtScreen({super.key});

  @override
  State<TraceArtScreen> createState() => _TraceArtScreenState();
}

class _TraceArtScreenState extends State<TraceArtScreen> {
  final ScrollController _scroll = ScrollController();
  String _category = 'beginner';
  bool _pinned = false;
  double _carouselExtent = 300;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(() {
      final p = _scroll.offset >= _carouselExtent - 1;
      if (p != _pinned) setState(() => _pinned = p);
    });
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  void _open(String traceId) {
    Navigator.of(context)
        .push(slideRoute(TracePreviewScreen(item: traceItemById(traceId))));
  }

  void _selectCategory(String id) {
    if (id == _category) return;
    setState(() => _category = id);
    if (_scroll.hasClients && _scroll.offset > _carouselExtent) {
      final max = _scroll.position.maxScrollExtent;
      _scroll.jumpTo(_carouselExtent < max ? _carouselExtent : max);
    }
  }

  @override
  Widget build(BuildContext context) {
    AppScope.of(context); // rebuild on language change
    final topInset = MediaQuery.of(context).padding.top;
    final width = MediaQuery.of(context).size.width;
    final carouselH = (width - 24) * 0.64;
    _carouselExtent = carouselH + 16;
    final items = traceItemsFor(_category);

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark,
      child: Scaffold(
        backgroundColor: _pageBg,
        body: Column(
          children: [
            // Status-bar strip turns cyan once the chips are pinned.
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              height: topInset,
              color: _pinned ? _pinnedBar : _pageBg,
            ),
            Expanded(
              child: CustomScrollView(
                controller: _scroll,
                slivers: [
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
                      child: SizedBox(
                        height: carouselH,
                        child: _Carousel(onDraw: _open),
                      ),
                    ),
                  ),
                  SliverPersistentHeader(
                    pinned: true,
                    delegate: _ChipsHeader(
                      pinned: _pinned,
                      rebuildKey:
                          '$_category|$_pinned|${AppScope.read(context).lang}',
                      child: _TraceChips(
                          selected: _category, onSelected: _selectCategory),
                    ),
                  ),
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(18, 10, 18, 28),
                    sliver: SliverGrid(
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        mainAxisSpacing: 22,
                        crossAxisSpacing: 22,
                        childAspectRatio: 1,
                      ),
                      delegate: SliverChildBuilderDelegate(
                        (context, i) => _TraceTile(
                          item: items[i],
                          onTap: () => _open(items[i].id),
                        ),
                        childCount: items.length,
                      ),
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

// ================================================================ carousel
class _Carousel extends StatefulWidget {
  const _Carousel({required this.onDraw});
  final ValueChanged<String> onDraw;

  @override
  State<_Carousel> createState() => _CarouselState();
}

class _CarouselState extends State<_Carousel> {
  static const int _loopStart = 1000;
  final PageController _pc =
      PageController(initialPage: _loopStart * kTraceBanners.length);
  Timer? _timer;
  int _index = 0;

  @override
  void initState() {
    super.initState();
    _startAuto();
  }

  void _startAuto() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 3), (_) {
      if (!_pc.hasClients) return;
      _pc.nextPage(
          duration: const Duration(milliseconds: 550),
          curve: Curves.easeInOutCubic);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _pc.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final n = kTraceBanners.length;
    return ClipRRect(
      borderRadius: BorderRadius.circular(22),
      child: Stack(
        children: [
          // Pause auto-play while the user is swiping.
          NotificationListener<ScrollNotification>(
            onNotification: (note) {
              if (note is ScrollStartNotification &&
                  note.dragDetails != null) {
                _timer?.cancel();
              } else if (note is ScrollEndNotification) {
                _startAuto();
              }
              return false;
            },
            child: PageView.builder(
              controller: _pc,
              onPageChanged: (p) => setState(() => _index = p % n),
              itemBuilder: (_, p) =>
                  _BannerSlide(banner: kTraceBanners[p % n], index: p % n),
            ),
          ),
          // Back button
          const Positioned(
            left: 14,
            top: 14,
            child: BackCircle(),
          ),
          // Draw button
          Positioned(
            right: 16,
            bottom: 18,
            child: Pressable(
              onTap: () => widget.onDraw(kTraceBanners[_index].traceId),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 18, vertical: 9),
                decoration: BoxDecoration(
                  color: const Color(0xFF3786D7),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(tr(context, 'draw'),
                        style: nunito(17,
                            weight: FontWeight.w700, color: Colors.white)),
                    const SizedBox(width: 8),
                    const Icon(Icons.edit_rounded,
                        color: Colors.white, size: 18),
                  ],
                ),
              ),
            ),
          ),
          // Dots
          Positioned(
            left: 0,
            right: 0,
            bottom: 12,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(n, (i) {
                final active = i == _index;
                return AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  width: active ? 26 : 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: active
                        ? const Color(0xFF1F5FE0)
                        : Colors.white.withOpacity(0.75),
                    borderRadius: BorderRadius.circular(4),
                  ),
                );
              }),
            ),
          ),
        ],
      ),
    );
  }
}

class _BannerSlide extends StatelessWidget {
  const _BannerSlide({required this.banner, required this.index});
  final TraceBanner banner;
  final int index;

  @override
  Widget build(BuildContext context) {
    return ArtSlot(
      asset: 'trace_banner_${index + 1}.png',
      fit: BoxFit.cover,
      fallback: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: banner.colors,
          ),
        ),
        child: Stack(
          children: [
            Positioned(
              left: -10,
              bottom: -20,
              child: Emoji(banner.emoji, size: 170),
            ),
            Positioned(
              right: 20,
              top: 26,
              child: OutlinedText(banner.title,
                  size: 34,
                  height: 0.95,
                  align: TextAlign.right,
                  fill: const Color(0xFFFFE14D),
                  stroke: const Color(0xFF3A1D00),
                  strokeWidth: 6),
            ),
          ],
        ),
      ),
    );
  }
}

// ================================================================ chips
class _ChipsHeader extends SliverPersistentHeaderDelegate {
  _ChipsHeader(
      {required this.child, required this.pinned, required this.rebuildKey});
  final Widget child;
  final bool pinned;
  final String rebuildKey;

  @override
  double get maxExtent => 64;
  @override
  double get minExtent => 64;

  @override
  Widget build(
          BuildContext context, double shrinkOffset, bool overlapsContent) =>
      Container(color: _pageBg, child: child);

  @override
  bool shouldRebuild(covariant _ChipsHeader old) =>
      old.rebuildKey != rebuildKey;
}

class _TraceChips extends StatelessWidget {
  const _TraceChips({required this.selected, required this.onSelected});
  final String selected;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.fromLTRB(14, 8, 14, 10),
      itemCount: kTraceCategories.length,
      separatorBuilder: (_, __) => const SizedBox(width: 10),
      itemBuilder: (context, i) {
        final c = kTraceCategories[i];
        final sel = c.id == selected;
        return GestureDetector(
          onTap: () {
            AppScope.read(context).tap();
            onSelected(c.id);
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            constraints: const BoxConstraints(minWidth: 96),
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              gradient: sel
                  ? const LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Color(0xFFB5D9FF), Color(0xFF93C5FB)],
                    )
                  : null,
              color: sel ? null : Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                  color:
                      sel ? const Color(0xFF93C5FB) : const Color(0xFFE2E4E8),
                  width: 1.5),
              boxShadow: sel
                  ? const [
                      BoxShadow(color: Color(0xFF5E9FE6), offset: Offset(0, 3))
                    ]
                  : null,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (c.emoji != null) ...[
                  Emoji(c.emoji!, size: 22),
                  const SizedBox(width: 4),
                ],
                Text(tr(context, c.key),
                    style: nunito(17,
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

// ================================================================ tiles
class _TraceTile extends StatelessWidget {
  const _TraceTile({required this.item, required this.onTap});
  final TraceItem item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: onTap,
      pressedScale: 0.93,
      child: Container(
        decoration: traceCardDecoration(item),
        padding: const EdgeInsets.all(14),
        child: Center(child: TraceItemArt(item: item)),
      ),
    );
  }
}
