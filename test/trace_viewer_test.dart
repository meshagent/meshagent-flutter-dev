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

  group('LiveMetricAccumulator', () {
    test('aggregates sum metrics from realtime OTLP exports', () {
      final accumulator = LiveMetricAccumulator();

      accumulator.addExport(
        OtlpMetricExport.fromJson({
          'resourceMetrics': [
            {
              'scopeMetrics': [
                {
                  'metrics': [
                    {
                      'name': 'tokens',
                      'unit': 'input_tokens',
                      'sum': {
                        'dataPoints': [
                          {
                            'startTimeUnixNano': '1',
                            'timeUnixNano': '2',
                            'asInt': '7',
                            'attributes': [
                              {
                                'key': 'provider',
                                'value': {'stringValue': 'openai'},
                              },
                              {
                                'key': 'model',
                                'value': {'stringValue': 'gpt-test'},
                              },
                            ],
                          },
                          {
                            'startTimeUnixNano': '1',
                            'timeUnixNano': '3',
                            'asInt': '5',
                            'attributes': [
                              {
                                'key': 'provider',
                                'value': {'stringValue': 'openai'},
                              },
                              {
                                'key': 'model',
                                'value': {'stringValue': 'gpt-test'},
                              },
                            ],
                          },
                        ],
                      },
                    },
                  ],
                },
              ],
            },
          ],
        }),
      );

      final snapshot = accumulator.snapshots.single;
      expect(snapshot.key, 'openai/gpt-test/tokens');
      expect(snapshot.kind, LiveMetricKind.sum);
      expect(snapshot.value, 12);
    });

    test('aggregates histogram metrics from realtime OTLP exports', () {
      final accumulator = LiveMetricAccumulator();

      accumulator.addExport(
        OtlpMetricExport.fromJson({
          'resourceMetrics': [
            {
              'scopeMetrics': [
                {
                  'metrics': [
                    {
                      'name': 'http.client.request.duration',
                      'unit': 's',
                      'histogram': {
                        'aggregationTemporality':
                            'AGGREGATION_TEMPORALITY_DELTA',
                        'dataPoints': [
                          {
                            'startTimeUnixNano': '1',
                            'timeUnixNano': '2',
                            'count': '3',
                            'sum': 0.21,
                            'min': 0.02,
                            'max': 0.13,
                            'bucketCounts': ['1', '2', '0'],
                            'explicitBounds': [0.05, 0.1],
                          },
                        ],
                      },
                    },
                  ],
                },
              ],
            },
          ],
        }),
      );

      accumulator.addExport(
        OtlpMetricExport.fromJson({
          'resourceMetrics': [
            {
              'scopeMetrics': [
                {
                  'metrics': [
                    {
                      'name': 'http.client.request.duration',
                      'unit': 's',
                      'histogram': {
                        'aggregationTemporality':
                            'AGGREGATION_TEMPORALITY_DELTA',
                        'dataPoints': [
                          {
                            'startTimeUnixNano': '1',
                            'timeUnixNano': '3',
                            'count': '2',
                            'sum': 0.4,
                            'min': 0.15,
                            'max': 0.25,
                            'bucketCounts': ['0', '0', '2'],
                            'explicitBounds': [0.05, 0.1],
                          },
                        ],
                      },
                    },
                  ],
                },
              ],
            },
          ],
        }),
      );

      final snapshot = accumulator.snapshots.single;
      expect(snapshot.key, 'http.client.request.duration');
      expect(snapshot.kind, LiveMetricKind.histogram);
      expect(snapshot.count, 5);
      expect(snapshot.sum, closeTo(0.61, 0.0001));
      expect(snapshot.min, 0.02);
      expect(snapshot.max, 0.25);
      expect(snapshot.bucketCounts, [1, 2, 2]);
      expect(snapshot.explicitBounds, [0.05, 0.1]);
      expect(snapshot.average, closeTo(0.122, 0.0001));
      expect(snapshot.estimateQuantile(0.50), 0.1);
      expect(snapshot.estimateQuantile(0.95), 0.1);
      expect(snapshot.format(), contains('count=5'));
      expect(snapshot.format(), contains('buckets=[<=0.0500:1'));
    });

    test('aggregates histogram-shaped session metric API rows', () {
      final accumulator = LiveMetricAccumulator();

      expect(
        accumulator.addSessionMetric({
          'kind': 'histogram',
          'metric_name': 'http.client.request.duration',
          'metric_unit': 's',
          'metric_attributes': {'http.request.method': 'GET'},
          'count': 4,
          'sum': 0.8,
          'min': 0.1,
          'max': 0.4,
          'bucket_counts': [1, 3],
          'explicit_bounds': [0.2],
        }),
        isTrue,
      );

      final snapshot = accumulator.snapshots.single;
      expect(snapshot.kind, LiveMetricKind.histogram);
      expect(snapshot.count, 4);
      expect(snapshot.sum, 0.8);
      expect(snapshot.bucketCounts, [1, 3]);
      expect(snapshot.explicitBounds, [0.2]);
    });
  });
}
