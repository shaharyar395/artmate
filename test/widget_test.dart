import 'package:draw_together/battle/battle_art.dart';
import 'package:draw_together/battle/battle_data.dart';
import 'package:draw_together/core/dt_catalog.dart';
import 'package:draw_together/core/trace_art_data.dart';
import 'package:draw_together/core/trace_catalog.dart';
import 'package:draw_together/core/trace_steps.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('every picture used by the app has drawable steps', () {
    final missing = <String>[];
    for (final item in kTraceItems) {
      if (!kTraceArt.containsKey(item.id)) missing.add('trace item ${item.id}');
      if (buildTraceSteps(item).isEmpty) missing.add('trace steps ${item.id}');
    }
    for (final t in [...kTemplates4, ...kTemplates2]) {
      for (final id in t.items) {
        if (!kTraceArt.containsKey(id)) missing.add('battle ${t.id} -> $id');
        if (battleSteps(id).isEmpty) missing.add('battle steps $id');
      }
    }
    for (final t in kDtTemplates) {
      for (final id in [t.left, t.right]) {
        if (!kTraceArt.containsKey(id)) {
          missing.add('draw together ${t.id} -> $id');
        }
        if (buildTraceSteps(traceItemById(id)).isEmpty) {
          missing.add('draw together steps $id');
        }
      }
    }
    expect(missing, isEmpty, reason: missing.join('\n'));
  });
}
