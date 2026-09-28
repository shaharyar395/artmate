import 'package:flutter/material.dart';

import '../core/trace_art_model.dart';
import '../core/trace_catalog.dart';
import 'common.dart';

/// Picture for a Trace Art item. Uses `assets/images/trace_<id>.png` if you
/// add one, otherwise the built-in vector drawing.
class TraceItemArt extends StatelessWidget {
  const TraceItemArt({super.key, required this.item, this.size = 90});
  final TraceItem item;
  final double size;

  @override
  Widget build(BuildContext context) {
    return ArtSlot(
      asset: 'trace_${item.id}.png',
      fallback: SizedBox.expand(
        child: CustomPaint(painter: _ArtPainter(item.art)),
      ),
    );
  }
}

class _ArtPainter extends CustomPainter {
  _ArtPainter(this.art);
  final TraceArt art;

  @override
  void paint(Canvas canvas, Size size) => paintTraceArt(canvas, size, art);

  @override
  bool shouldRepaint(covariant _ArtPainter old) => old.art != art;
}

/// Card background for a Trace Art item (black for Neon, white otherwise).
BoxDecoration traceCardDecoration(TraceItem item) => BoxDecoration(
      color: item.isNeon ? null : Colors.white,
      gradient: item.isNeon
          ? const RadialGradient(
              colors: [Color(0xFF1E1E26), Color(0xFF050507)],
              radius: 0.9,
            )
          : null,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(
          color: item.isNeon ? const Color(0xFF2A2A33) : const Color(0xFFEDEFF2),
          width: 1.5),
      boxShadow: const [
        BoxShadow(color: Color(0xFFD5DEE6), offset: Offset(0, 5)),
      ],
    );
