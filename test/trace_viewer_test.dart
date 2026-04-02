import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
import 'package:meshagent_flutter_dev/trace_viewer.dart';

Span _span({
  required String traceId,
  required String spanId,
  String? parentSpanId,
  String name = 'span',
  int startTimeUnixNano = 10,
  int endTimeUnixNano = 20,
}) {
  return Span(
    traceId: traceId,
    spanId: spanId,
    parentSpanId: parentSpanId,
    name: name,
    kind: SpanKind.internal,
    startTimeUnixNano: startTimeUnixNano,
    endTimeUnixNano: endTimeUnixNano,
  );
}

void main() {
  group('timestamp formatting', () {
    test('includes seconds and milliseconds', () {
      final previousLocale = Intl.defaultLocale;
      Intl.defaultLocale = 'en_US';
      addTearDown(() => Intl.defaultLocale = previousLocale);

      expect(
        formatTraceViewerTimestamp(DateTime(2026, 4, 2, 14, 17, 23, 456)),
        'Thursday, April 2, 2026 2:17:23.456 PM',
      );
    });
  });

  group('SpanCollection', () {
    test('dedupes identical spans by trace and span id', () {
      final spans = SpanCollection();
      final span = _span(traceId: 'trace-1', spanId: 'span-1');

      expect(spans.add(span), isTrue);
      expect(spans.add(span), isFalse);

      expect(spans.toList(), hasLength(1));
      expect(spans.getRootSpans().toList(), hasLength(1));
    });

    test('replaces an existing span instead of duplicating it', () {
      final spans = SpanCollection();
      final original = _span(
        traceId: 'trace-1',
        spanId: 'span-1',
        endTimeUnixNano: 20,
      );
      final updated = _span(
        traceId: 'trace-1',
        spanId: 'span-1',
        endTimeUnixNano: 40,
      );

      spans.add(original);

      expect(spans.add(updated), isTrue);
      expect(spans.toList(), hasLength(1));
      expect(spans.first.endTimeUnixNano, 40);
      expect(spans.getRootSpans().single.endTimeUnixNano, 40);
    });

    test('replaces duplicated child spans without duplicating tree nodes', () {
      final spans = SpanCollection();
      final parent = _span(traceId: 'trace-1', spanId: 'parent');
      final child = _span(
        traceId: 'trace-1',
        spanId: 'child',
        parentSpanId: 'parent',
        endTimeUnixNano: 20,
      );
      final updatedChild = _span(
        traceId: 'trace-1',
        spanId: 'child',
        parentSpanId: 'parent',
        endTimeUnixNano: 60,
      );

      spans.add(parent);
      spans.add(child);

      expect(spans.add(updatedChild), isTrue);

      final children = spans.getChildren('parent').toList();
      expect(children, hasLength(1));
      expect(children.single.endTimeUnixNano, 60);
      expect(spans.toList(), hasLength(2));
    });
  });
}
