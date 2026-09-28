import 'dart:ui';

import 'trace_art_model.dart';
import 'trace_catalog.dart';

/// Tracing steps for a picture: each guide part of its drawing, sampled to
/// normalized 0..1 points, in drawing order.
List<List<Offset>> traceGuidesFor(TraceItem item) =>
    [for (final p in item.art.guideParts) samplePart(p)];
