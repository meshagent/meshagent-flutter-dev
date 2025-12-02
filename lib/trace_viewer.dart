import 'dart:async';
import 'dart:math';

import 'package:collection/collection.dart';
import 'package:flutter/material.dart';

import 'package:google_fonts/google_fonts.dart';
import 'dart:convert';

import 'package:meshagent/room_server_client.dart';
import 'package:meshagent_flutter_shadcn/meshagent_flutter_shadcn.dart';
import './ansi.dart';
import 'package:shadcn_ui/shadcn_ui.dart';
import 'package:super_sliver_list/super_sliver_list.dart';

dynamic trimStrings(dynamic v) {
  if (v is String) {
    if (v.length > 128) {
      return "${v.substring(0, 128)}...";
    }
  }
  return v;
}

class SpanCollection extends Iterable<Span> {
  SpanCollection();

  final List<Span> _spans = [];
  final List<Span> _rootSpans = [];
  final Map<String, List<Span>> _childSpans = {};

  void add(Span span) {
    _spans.add(span);
    final parentSpanId = span.parentSpanId;
    if (parentSpanId != null) {
      if (!_childSpans.containsKey(parentSpanId)) {
        _childSpans[parentSpanId] = [];
      }
      _childSpans[parentSpanId]!.add(span);
    } else {
      _rootSpans.add(span);
    }
  }

  Iterable<Span> getRootSpans() {
    return _rootSpans;
  }

  Iterable<Span> getChildren(String parentSpanId) {
    return _childSpans[parentSpanId] ?? [];
  }

  @override
  Iterator<Span> get iterator {
    return _spans.iterator;
  }
}

class TraceViewer extends StatelessWidget {
  const TraceViewer({
    super.key,
    required this.spans,
    this.filterNames,
    this.filterParent,
    required this.depth,
  });

  final Set<String>? filterNames;
  final String? filterParent;
  final SpanCollection spans;
  final int depth;

  @override
  Widget build(BuildContext context) {
    final List<Widget> children = [];

    int? start;
    int? end;
    for (final span in spans) {
      if (start == null || span.startTimeUnixNano < start) {
        start = span.startTimeUnixNano;
      }

      if (end == null || span.startTimeUnixNano > end) {
        end = span.startTimeUnixNano;
      }
    }

    start ??= DateTime.now().toUtc().microsecondsSinceEpoch * 1000;
    end ??= DateTime.now().toUtc().microsecondsSinceEpoch * 1000;

    for (final node
        in filterParent == null
            ? spans.getRootSpans()
            : spans.getChildren(filterParent!)) {
      if (filterNames == null || filterNames!.contains(node.name)) {
        children.add(
          SpanTreeNodeViewer(
            node: node,
            spans: spans,
            start: start,
            end: end,
            depth: depth,
          ),
        );
      }
    }

    return Column(mainAxisSize: MainAxisSize.min, children: children);
  }
}

class SpanTreeNodeViewer extends StatefulWidget {
  const SpanTreeNodeViewer({
    super.key,
    required this.node,
    required this.spans,
    required this.start,
    required this.end,
    required this.depth,
  });

  final SpanCollection spans;
  final Span node;
  final int start;
  final int end;
  final int depth;

  @override
  State<StatefulWidget> createState() {
    return _SpanTreeNodeViewer();
  }

  static final visualizers = <String, Widget Function(BuildContext, Span)>{
    "chatbot.thread.message": (context, span) => Container(
      padding: EdgeInsets.all(10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            "${span.attributes.where((a) => a.key == "from_participant_name").firstOrNull?.value.toString() ?? ""}:",
            style: ShadTheme.of(context).textTheme.p,
          ),

          ChatBubble(
            mine: false,
            text:
                span.attributes
                    .where((a) => a.key == "text")
                    .firstOrNull
                    ?.value
                    .toString() ??
                "",
          ),
        ],
      ),
    ),
  };
}

class _SpanTreeNodeViewer extends State<SpanTreeNodeViewer> {
  bool expanded = false;

  @override
  void didUpdateWidget(covariant SpanTreeNodeViewer oldWidget) {
    super.didUpdateWidget(oldWidget);
    setState(() {});
  }

  Widget visualize(Span node) {
    if (SpanTreeNodeViewer.visualizers[node.name] != null) {
      return SpanTreeNodeViewer.visualizers[node.name]!(context, node);
    }
    return Container(
      width: double.infinity,
      margin: EdgeInsets.all(8),
      padding: EdgeInsets.all(8),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Wrap(
        children: [
          for (final a in node.attributes) ...[
            Padding(
              padding: EdgeInsets.symmetric(vertical: 4, horizontal: 4),
              child: ShadBadge(
                child: Text(
                  "${a.key} = ${trimStrings(a.value)}",
                  maxLines: 1,
                  textAlign: TextAlign.start,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget spanTooltip(Span node, Widget child) {
    return ShadTooltip(
      builder: (context) => SizedBox(
        width: 400,
        child: DefaultTextStyle(
          style: ShadTheme.of(context).textTheme.p,
          textAlign: TextAlign.left,
          child: visualize(node),
        ),
      ),
      child: child,
    );
  }

  @override
  Widget build(BuildContext context) {
    final node = widget.node;
    final duration =
        ((node.endTimeUnixNano - node.startTimeUnixNano) / 1000000000).asFixed(
          2,
        );

    final totalDuration = widget.end - widget.start;
    final startPct =
        (node.startTimeUnixNano - widget.start) /
        (totalDuration == 0 ? 1 : totalDuration);
    final durationPct = min(
      1,
      (node.endTimeUnixNano - node.startTimeUnixNano) /
          (totalDuration == 0 ? 1 : totalDuration),
    );

    return Column(
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            spanTooltip(
              node,
              ShadButton.link(
                hoverForegroundColor: node.status?.code == "STATUS_CODE_ERROR"
                    ? Colors.red
                    : null,
                foregroundColor: node.status?.code == "STATUS_CODE_ERROR"
                    ? Colors.red
                    : null,
                onTapDown: (_) {
                  setState(() {
                    expanded = !expanded;
                  });
                },
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Padding(
                      padding: EdgeInsets.only(right: 10),
                      child:
                          (widget.spans
                              .getChildren(widget.node.spanId)
                              .isNotEmpty)
                          ? Icon(
                              expanded
                                  ? LucideIcons.chevronDown
                                  : LucideIcons.chevronRight,
                            )
                          : Icon(LucideIcons.dot),
                    ),
                    Padding(
                      padding: EdgeInsets.only(right: 10),
                      child: switch (node.status?.code) {
                        "STATUS_CODE_ERROR" => Icon(
                          LucideIcons.bug,
                          color: Colors.red,
                        ),
                        _ => Icon(
                          LucideIcons.clock,
                          color: ShadTheme.of(context).colorScheme.foreground,
                        ),
                      },
                    ),
                    SizedBox(
                      width: 300 - widget.depth * 20,
                      child: Text(
                        duration == 0
                            ? node.name
                            : "${node.name} (${duration}s)",
                        maxLines: 1,
                        textAlign: TextAlign.start,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: EdgeInsets.all(8),
                    child: LayoutBuilder(
                      builder: (context, constraints) => SizedBox(
                        height: 30,
                        child: Stack(
                          children: [
                            Positioned(
                              top: 0,
                              bottom: 0,
                              left: startPct * constraints.maxWidth,
                              width: durationPct * constraints.maxWidth,
                              child: ShadTooltip(
                                builder: (context) {
                                  return Padding(
                                    padding: EdgeInsets.all(16),
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          node.name,
                                          style: ShadTheme.of(
                                            context,
                                          ).textTheme.muted,
                                        ),
                                        Text(
                                          "Started: ${DateFormat.yMMMMEEEEd().add_jm().format(DateTime.fromMicrosecondsSinceEpoch((node.startTimeUnixNano / 1000).toInt(), isUtc: true).toLocal())}",
                                        ),
                                        Text(
                                          "Ended: ${DateFormat.yMMMMEEEEd().add_jm().format(DateTime.fromMicrosecondsSinceEpoch((node.startTimeUnixNano / 1000).toInt(), isUtc: true).toLocal())}",
                                        ),
                                        Text("Duration: ${duration}s"),
                                      ],
                                    ),
                                  );
                                },
                                child: Container(
                                  decoration: BoxDecoration(
                                    border: Border.all(
                                      color: Colors.green,
                                      width: 3,
                                    ),
                                    borderRadius: BorderRadius.circular(3),
                                    color: Colors.lightGreenAccent,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                  if (expanded && (node.status?.code == "STATUS_CODE_ERROR"))
                    Text(
                      node.status?.message ?? "an error was encountered",
                      style: TextStyle(color: Colors.red),
                    ),
                ],
              ),
            ),
          ],
        ),

        if (expanded)
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(width: 20),
              Expanded(
                child: TraceViewer(
                  spans: widget.spans,
                  filterParent: node.spanId,
                  depth: widget.depth + 1,
                ),
              ),
            ],
          ),
      ],
    );
  }
}

class LiveLogViewer extends StatefulWidget {
  const LiveLogViewer({super.key, required this.events});

  final Stream<RoomEvent> events;

  @override
  State createState() => _LiveLogViewer();
}

class _LiveLogViewer extends State<LiveLogViewer> {
  @override
  void initState() {
    super.initState();

    sub = widget.events.listen(onEvent);
  }

  StreamSubscription? sub;

  final List<LogRecord> logs = [];

  void onEvent(RoomEvent event) {
    if (event is RoomLogEvent && event.name == "otel.log") {
      var dirty = false;

      final export = OtlpLogExport.fromJson(event.data);

      for (final resourceLogs in export.resourceLogs) {
        for (final log in resourceLogs.scopeLogs) {
          logs.addAll(log.logRecords);
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              if (scrollController.position.extentAfter < 100) {
                scrollController.jumpTo(
                  scrollController.position.maxScrollExtent,
                );
              }
            }
          });
          dirty = true;
        }
      }

      if (dirty) {
        setState(() {});
      }
    }
  }

  @override
  void dispose() {
    sub?.cancel();
    super.dispose();
  }

  final scrollController = ScrollController();

  @override
  Widget build(BuildContext context) {
    return SelectionArea(
      child: SuperListView(
        controller: scrollController,
        padding: const EdgeInsets.all(20.0),
        children: [
          for (final m in logs) ...[
            SizedBox(
              width: double.infinity,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ShadGestureDetector(
                    cursor: SystemMouseCursors.click,
                    onTap: () {
                      showShadSheet(
                        side: ShadSheetSide.right,
                        context: context,
                        builder: (context) => ShadSheet(
                          title: Text("Log Details"),
                          constraints: BoxConstraints(
                            minWidth: 500,
                            maxWidth: 500,
                          ),
                          child: SelectionArea(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text.rich(
                                  TextSpan(
                                    children: [
                                      TextSpan(
                                        text: "timestamp: ",
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      TextSpan(
                                        text: DateFormat.yMMMMEEEEd()
                                            .add_jm()
                                            .format(
                                              DateTime.fromMicrosecondsSinceEpoch(
                                                (m.timeUnixNano / 1000).toInt(),
                                                isUtc: true,
                                              ).toLocal(),
                                            ),
                                      ),
                                    ],
                                  ),
                                ),
                                Text.rich(
                                  TextSpan(
                                    children: [
                                      TextSpan(
                                        text: "severity: ",
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      TextSpan(text: m.severity.name),
                                    ],
                                  ),
                                ),

                                for (final attribute in m.attributes)
                                  Text.rich(
                                    TextSpan(
                                      children: [
                                        TextSpan(
                                          text: "${attribute.key}: ",
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        TextSpan(text: "${attribute.value}"),
                                      ],
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                    child: Padding(
                      padding: EdgeInsets.symmetric(vertical: 3),
                      child: Icon(LucideIcons.chevronRight),
                    ),
                  ),

                  SizedBox(width: 6),
                  Expanded(
                    child: Text.rich(
                      TextSpan(
                        style: GoogleFonts.sourceCodePro(
                          color: switch (m.severity) {
                            Severity.warn => Colors.orange,
                            Severity.warn2 => Colors.orange,
                            Severity.warn3 => Colors.orange,
                            Severity.warn4 => Colors.orange,
                            Severity.error => Colors.red,
                            Severity.error2 => Colors.red,
                            Severity.error3 => Colors.red,
                            Severity.error4 => Colors.red,
                            _ => ShadTheme.of(context).colorScheme.foreground,
                          },
                          height: 1.5,
                        ),
                        children: [ansiToTextSpan(m.body)],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class LiveMetricsViewer extends StatefulWidget {
  const LiveMetricsViewer({super.key, required this.events, this.pricing});

  final Map<String, dynamic>? pricing;
  final Stream<RoomEvent> events;

  @override
  State createState() => _LiveMetricsViewer();
}

class _LiveMetricsViewer extends State<LiveMetricsViewer> {
  @override
  void initState() {
    super.initState();

    sub = widget.events.listen(onEvent);
  }

  StreamSubscription? sub;

  final List<ScopeMetrics> metrics = [];
  final Map<String, num?> values = {};
  final Map<String, String> labels = {};

  void onEvent(RoomEvent event) {
    if (event is RoomLogEvent && event.name == "otel.metric") {
      var dirty = false;

      final export = OtlpMetricExport.fromJson(event.data);
      for (final rm in export.resourceMetrics) {
        for (final sm in rm.scopeMetrics) {
          for (final metric in sm.metrics) {
            var name = metric.name;
            String? model;
            String? provider;
            for (final dp in metric.sum?.dataPoints ?? <NumberDataPoint>[]) {
              for (final attr in dp.attributes) {
                if (attr.key == "model") {
                  model = attr.value;
                } else if (attr.key == "provider") {
                  provider = attr.value;
                }
              }
              if (model != null && provider != null) {
                name = "$provider/$model/$name";
              }
              labels[name] = metric.unit ?? "";
              values[name] = dp.value + (values[name] ?? 0);
            }
          }
        }
      }

      if (dirty || true) {
        setState(() {});
      }
    }
  }

  @override
  void dispose() {
    sub?.cancel();
    super.dispose();
  }

  String getPrice(Map<String, dynamic>? data, String key, num value) {
    final parts = key.split("/");
    if (parts.length == 3) {
      final provider = parts[0];
      final model = parts[1];
      final unit = parts[2];

      final price = data?[provider]?[model]?[unit] as num?;

      if (price != null) {
        return " = \$${(value * price).toStringAsFixed(5)}";
      }
    }
    return "";
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: SizedBox(
        width: double.infinity,
        child: Padding(
          padding: const EdgeInsets.all(20.0), // Adjust padding as needed
          child: SelectableText.rich(
            TextSpan(
              style: GoogleFonts.sourceCodePro(
                color: ShadTheme.of(context).colorScheme.foreground,
                height: 1.5,
              ),
              children: [
                for (final k in values.keys.toList()..sort())
                  TextSpan(
                    text:
                        "$k = ${values[k]} ${labels[k]}${getPrice(widget.pricing ?? const {}, k, values[k]!)}\n",
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class LiveTraceViewer extends StatefulWidget {
  const LiveTraceViewer({super.key, required this.events});

  final Stream<RoomEvent> events;

  @override
  State createState() => _LiveTraceViewerState();
}

class _LiveTraceViewerState extends State<LiveTraceViewer> {
  @override
  void initState() {
    super.initState();

    sub = widget.events.listen(onEvent);
  }

  StreamSubscription? sub;
  final spans = SpanCollection();

  void onEvent(RoomEvent event) {
    if (event is RoomLogEvent && event.name == "otel.trace") {
      final trace = OtlpTraceExport.fromJson(event.data);
      var dirty = false;
      for (final rs in trace.resourceSpans) {
        for (final ss in rs.scopeSpans) {
          for (final span in ss.spans) {
            spans.add(span);
            dirty = true;
          }
        }
      }

      if (dirty) {
        setState(() {});
      }
    }
  }

  @override
  void dispose() {
    sub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListView(children: [TraceViewer(spans: spans, depth: 1)]);
  }
}

// otel_trace.dart
/// ─────────────────────────────────────────────────────────────────────────────
///  ENUMS & VALUE HELPERS
/// ─────────────────────────────────────────────────────────────────────────────

enum SpanKind { unspecified, internal, server, client, producer, consumer }

SpanKind _kindFromJson(String? v) => switch (v) {
  'SPAN_KIND_INTERNAL' => SpanKind.internal,
  'SPAN_KIND_SERVER' => SpanKind.server,
  'SPAN_KIND_CLIENT' => SpanKind.client,
  'SPAN_KIND_PRODUCER' => SpanKind.producer,
  'SPAN_KIND_CONSUMER' => SpanKind.consumer,
  _ => SpanKind.unspecified,
};

String _kindToJson(SpanKind k) => switch (k) {
  SpanKind.internal => 'SPAN_KIND_INTERNAL',
  SpanKind.server => 'SPAN_KIND_SERVER',
  SpanKind.client => 'SPAN_KIND_CLIENT',
  SpanKind.producer => 'SPAN_KIND_PRODUCER',
  SpanKind.consumer => 'SPAN_KIND_CONSUMER',
  SpanKind.unspecified => 'SPAN_KIND_UNSPECIFIED',
};

dynamic _unwrapValue(Map<String, dynamic> wrapped) =>
    wrapped.entries.first.value; // {stringValue: "..."} → "..."

Map<String, dynamic> _wrapValue(dynamic v) {
  String key = switch (v) {
    String() => 'stringValue',
    bool() => 'boolValue',
    int() => 'intValue',
    double() => 'doubleValue',
    List() => 'arrayValue',
    Map() => 'kvlistValue',
    _ => 'stringValue',
  };
  return {key: v};
}

/// ─────────────────────────────────────────────────────────────────────────────
///  MODEL CLASSES
/// ─────────────────────────────────────────────────────────────────────────────

class Attribute {
  Attribute(this.key, this.value);
  final String key;
  final dynamic value;

  factory Attribute.fromJson(Map<String, dynamic> j) =>
      Attribute(j['key'], _unwrapValue(j['value'] as Map<String, dynamic>));

  Map<String, dynamic> toJson() => {'key': key, 'value': _wrapValue(value)};
}

class Status {
  Status({required this.code, this.message});
  final String code; // 0=UNSET, 1=OK, 2=ERROR (per OTEL proto enum)
  final String? message;

  factory Status.fromJson(Map<String, dynamic> j) =>
      Status(code: j['code'] ?? "STATUS_CODE_UNSET", message: j['message']);

  Map<String, dynamic> toJson() => {
    'code': code,
    if (message != null) 'message': message,
  };
}

class Span {
  Span({
    required this.traceId,
    required this.spanId,
    this.parentSpanId,
    required this.name,
    required this.kind,
    required this.startTimeUnixNano,
    required this.endTimeUnixNano,
    this.attributes = const [],
    this.status,
    this.flags,
  });

  final String traceId; // base64-encoded by OTLP/JSON
  final String spanId; // base64-encoded
  final String? parentSpanId;
  final String name;
  final SpanKind kind;
  final int startTimeUnixNano;
  final int endTimeUnixNano;
  final List<Attribute> attributes;
  final Status? status;
  final int? flags;

  factory Span.fromJson(Map<String, dynamic> j) => Span(
    traceId: j['traceId'],
    spanId: j['spanId'],
    parentSpanId: j['parentSpanId'],
    name: j['name'] ?? '',
    kind: _kindFromJson(j['kind']),
    startTimeUnixNano: int.parse(j['startTimeUnixNano'].toString()),
    endTimeUnixNano: int.parse(j['endTimeUnixNano'].toString()),
    attributes: (j['attributes'] as List<dynamic>? ?? [])
        .cast<Map<String, dynamic>>()
        .map(Attribute.fromJson)
        .toList(),
    status: j['status'] != null ? Status.fromJson(j['status']) : null,
    flags: j['flags'],
  );

  Map<String, dynamic> toJson() => {
    'traceId': traceId,
    'spanId': spanId,
    if (parentSpanId != null) 'parentSpanId': parentSpanId,
    'name': name,
    'kind': _kindToJson(kind),
    'startTimeUnixNano': startTimeUnixNano,
    'endTimeUnixNano': endTimeUnixNano,
    if (attributes.isNotEmpty)
      'attributes': attributes.map((a) => a.toJson()).toList(),
    if (status != null) 'status': status!.toJson(),
    if (flags != null) 'flags': flags,
  };
}

/* ───────── Wrapper layers (ScopeSpans, ResourceSpans, Export) ───────── */

class Scope {
  Scope({required this.name});
  final String name;

  factory Scope.fromJson(Map<String, dynamic> j) =>
      Scope(name: j['name'] ?? '');

  Map<String, dynamic> toJson() => {'name': name};
}

class ScopeSpans {
  ScopeSpans({required this.scope, required this.spans});
  final Scope scope;
  final List<Span> spans;

  factory ScopeSpans.fromJson(Map<String, dynamic> j) => ScopeSpans(
    scope: Scope.fromJson(j['scope'] ?? const {}),
    spans: (j['spans'] as List<dynamic>? ?? [])
        .cast<Map<String, dynamic>>()
        .map(Span.fromJson)
        .toList(),
  );

  Map<String, dynamic> toJson() => {
    'scope': scope.toJson(),
    'spans': spans.map((s) => s.toJson()).toList(),
  };
}

class Resource {
  Resource({this.attributes = const []});
  final List<Attribute> attributes;

  factory Resource.fromJson(Map<String, dynamic> j) => Resource(
    attributes: (j['attributes'] as List<dynamic>? ?? [])
        .cast<Map<String, dynamic>>()
        .map(Attribute.fromJson)
        .toList(),
  );

  Map<String, dynamic> toJson() => {
    'attributes': attributes.map((a) => a.toJson()).toList(),
  };
}

class ResourceSpans {
  ResourceSpans({required this.resource, required this.scopeSpans});
  final Resource resource;
  final List<ScopeSpans> scopeSpans;

  factory ResourceSpans.fromJson(Map<String, dynamic> j) => ResourceSpans(
    resource: Resource.fromJson(j['resource'] ?? const {}),
    scopeSpans: (j['scopeSpans'] as List<dynamic>? ?? [])
        .cast<Map<String, dynamic>>()
        .map(ScopeSpans.fromJson)
        .toList(),
  );

  Map<String, dynamic> toJson() => {
    'resource': resource.toJson(),
    'scopeSpans': scopeSpans.map((s) => s.toJson()).toList(),
  };
}

class OtlpTraceExport {
  OtlpTraceExport({required this.resourceSpans});
  final List<ResourceSpans> resourceSpans;

  /// Convenience factory to parse straight from a JSON string.
  factory OtlpTraceExport.fromJsonString(String jsonStr) =>
      OtlpTraceExport.fromJson(json.decode(jsonStr) as Map<String, dynamic>);

  factory OtlpTraceExport.fromJson(Map<String, dynamic> j) => OtlpTraceExport(
    resourceSpans: (j['resourceSpans'] as List<dynamic>? ?? [])
        .cast<Map<String, dynamic>>()
        .map(ResourceSpans.fromJson)
        .toList(),
  );

  Map<String, dynamic> toJson() => {
    'resourceSpans': resourceSpans.map((r) => r.toJson()).toList(),
  };

  /// Helper to flatten all nested spans into a single list.
  List<Span> allSpans() => [
    for (final rs in resourceSpans)
      for (final ss in rs.scopeSpans) ...ss.spans,
  ];
}

/// ─────────────────────────────────────────────────────────────────────────────
///  LOG-SPECIFIC ENUMS & MODELS
/// ─────────────────────────────────────────────────────────────────────────────

enum Severity {
  unspecified,
  trace,
  trace2,
  trace3,
  trace4,
  debug,
  debug2,
  debug3,
  debug4,
  info,
  info2,
  info3,
  info4,
  warn,
  warn2,
  warn3,
  warn4,
  error,
  error2,
  error3,
  error4,
  fatal,
  fatal2,
  fatal3,
  fatal4,
}

Severity _sevFromJson(String? s) {
  if (s == null) return Severity.unspecified;
  final norm = s.replaceFirst('SEVERITY_NUMBER_', '').toLowerCase();
  return Severity.values.firstWhere(
    (e) => e.name == norm,
    orElse: () => Severity.unspecified,
  );
}

String _sevToJson(Severity sev) => 'SEVERITY_NUMBER_${sev.name.toUpperCase()}';

class LogRecord {
  LogRecord({
    required this.timeUnixNano,
    this.observedTimeUnixNano,
    required this.severity,
    this.severityText,
    required this.body,
    this.attributes = const [],
  });

  final int timeUnixNano;
  final int? observedTimeUnixNano;
  final Severity severity;
  final String? severityText;
  final dynamic body; // string / int / double / map / list …
  final List<Attribute> attributes;

  factory LogRecord.fromJson(Map<String, dynamic> j) => LogRecord(
    timeUnixNano: int.parse(j['timeUnixNano'].toString()),
    observedTimeUnixNano: j['observedTimeUnixNano'] != null
        ? int.parse(j['observedTimeUnixNano'].toString())
        : null,
    severity: _sevFromJson(j['severityNumber']),
    severityText: j['severityText'],
    body: _unwrapValue(j['body'] as Map<String, dynamic>),
    attributes: (j['attributes'] as List<dynamic>? ?? [])
        .cast<Map<String, dynamic>>()
        .map(Attribute.fromJson)
        .toList(),
  );

  Map<String, dynamic> toJson() => {
    'timeUnixNano': timeUnixNano,
    if (observedTimeUnixNano != null)
      'observedTimeUnixNano': observedTimeUnixNano,
    'severityNumber': _sevToJson(severity),
    if (severityText != null) 'severityText': severityText,
    'body': _wrapValue(body),
    if (attributes.isNotEmpty)
      'attributes': attributes.map((a) => a.toJson()).toList(),
  };
}

class ScopeLogs {
  ScopeLogs({required this.scope, required this.logRecords});
  final Scope scope;
  final List<LogRecord> logRecords;

  factory ScopeLogs.fromJson(Map<String, dynamic> j) => ScopeLogs(
    scope: Scope.fromJson(j['scope'] ?? const {}),
    logRecords: (j['logRecords'] as List<dynamic>? ?? [])
        .cast<Map<String, dynamic>>()
        .map(LogRecord.fromJson)
        .toList(),
  );

  Map<String, dynamic> toJson() => {
    'scope': scope.toJson(),
    'logRecords': logRecords.map((l) => l.toJson()).toList(),
  };
}

class ResourceLogs {
  ResourceLogs({required this.resource, required this.scopeLogs});
  final Resource resource;
  final List<ScopeLogs> scopeLogs;

  factory ResourceLogs.fromJson(Map<String, dynamic> j) => ResourceLogs(
    resource: Resource.fromJson(j['resource'] ?? const {}),
    scopeLogs: (j['scopeLogs'] as List<dynamic>? ?? [])
        .cast<Map<String, dynamic>>()
        .map(ScopeLogs.fromJson)
        .toList(),
  );

  Map<String, dynamic> toJson() => {
    'resource': resource.toJson(),
    'scopeLogs': scopeLogs.map((s) => s.toJson()).toList(),
  };
}

class OtlpLogExport {
  OtlpLogExport({required this.resourceLogs});
  final List<ResourceLogs> resourceLogs;

  /// Parse directly from a JSON string (file / network / etc.).
  factory OtlpLogExport.fromJsonString(String jsonStr) =>
      OtlpLogExport.fromJson(json.decode(jsonStr) as Map<String, dynamic>);

  factory OtlpLogExport.fromJson(Map<String, dynamic> j) => OtlpLogExport(
    resourceLogs: (j['resourceLogs'] as List<dynamic>? ?? [])
        .cast<Map<String, dynamic>>()
        .map(ResourceLogs.fromJson)
        .toList(),
  );

  Map<String, dynamic> toJson() => {
    'resourceLogs': resourceLogs.map((r) => r.toJson()).toList(),
  };

  /// Flatten all nested LogRecords into a single list for convenience.
  List<LogRecord> allLogs() => [
    for (final rl in resourceLogs)
      for (final sl in rl.scopeLogs) ...sl.logRecords,
  ];
}

// otel_metric.dart
// ─────────────────────────────────────────────────────────────────────────────
//  ENUMS & VALUE HELPERS
// ─────────────────────────────────────────────────────────────────────────────

enum AggregationTemporality { unspecified, delta, cumulative }

AggregationTemporality _aggFromJson(String? v) => switch (v) {
  'AGGREGATION_TEMPORALITY_DELTA' => AggregationTemporality.delta,
  'AGGREGATION_TEMPORALITY_CUMULATIVE' => AggregationTemporality.cumulative,
  _ => AggregationTemporality.unspecified,
};

String _aggToJson(AggregationTemporality t) => switch (t) {
  AggregationTemporality.delta => 'AGGREGATION_TEMPORALITY_DELTA',
  AggregationTemporality.cumulative => 'AGGREGATION_TEMPORALITY_CUMULATIVE',
  AggregationTemporality.unspecified => 'AGGREGATION_TEMPORALITY_UNSPECIFIED',
};

// We already have Attribute / _unwrapValue / _wrapValue helpers in the trace
// & log parsers – reuse them here.

// ─────────────────────────────────────────────────────────────────────────────
//  MODEL CLASSES
// ─────────────────────────────────────────────────────────────────────────────

/// Individual data-point for numeric metrics (sum / gauge).
class NumberDataPoint {
  NumberDataPoint({
    required this.startTimeUnixNano,
    required this.timeUnixNano,
    required this.value,
    this.attributes = const [],
  });

  final int startTimeUnixNano;
  final int timeUnixNano;
  final num value;
  final List<Attribute> attributes;

  factory NumberDataPoint.fromJson(Map<String, dynamic> j) {
    // OTLP/JSON may use asDouble, asInt, asUint.
    num _parseValue(Map<String, dynamic> m) {
      if (m.containsKey('asDouble')) return m['asDouble'] as num;
      if (m.containsKey('asInt')) return int.parse(m['asInt'].toString());
      if (m.containsKey('asUint')) return int.parse(m['asUint'].toString());
      return 0;
    }

    return NumberDataPoint(
      startTimeUnixNano: int.parse(j['startTimeUnixNano'].toString()),
      timeUnixNano: int.parse(j['timeUnixNano'].toString()),
      value: _parseValue(j),
      attributes: (j['attributes'] as List<dynamic>? ?? [])
          .cast<Map<String, dynamic>>()
          .map(Attribute.fromJson)
          .toList(),
    );
  }

  Map<String, dynamic> toJson() => {
    'startTimeUnixNano': startTimeUnixNano,
    'timeUnixNano': timeUnixNano,
    'asDouble': value is int ? (value as int).toDouble() : value,
    if (attributes.isNotEmpty)
      'attributes': attributes.map((a) => a.toJson()).toList(),
  };
}

/// OTLP Sum (monotonic or not, cumulative/delta).
class Sum {
  Sum({
    required this.dataPoints,
    this.aggregationTemporality = AggregationTemporality.unspecified,
    this.isMonotonic = false,
  });

  final List<NumberDataPoint> dataPoints;
  final AggregationTemporality aggregationTemporality;
  final bool isMonotonic;

  factory Sum.fromJson(Map<String, dynamic> j) => Sum(
    dataPoints: (j['dataPoints'] as List<dynamic>? ?? [])
        .cast<Map<String, dynamic>>()
        .map(NumberDataPoint.fromJson)
        .toList(),
    aggregationTemporality: _aggFromJson(j['aggregationTemporality']),
    isMonotonic: j['isMonotonic'] ?? false,
  );

  Map<String, dynamic> toJson() => {
    'dataPoints': dataPoints.map((p) => p.toJson()).toList(),
    'aggregationTemporality': _aggToJson(aggregationTemporality),
    'isMonotonic': isMonotonic,
  };
}

/// (Optional) Gauge – same payload shape as Sum *without* monotonic flag.
class Gauge {
  Gauge({required this.dataPoints});

  final List<NumberDataPoint> dataPoints;

  factory Gauge.fromJson(Map<String, dynamic> j) => Gauge(
    dataPoints: (j['dataPoints'] as List<dynamic>? ?? [])
        .cast<Map<String, dynamic>>()
        .map(NumberDataPoint.fromJson)
        .toList(),
  );

  Map<String, dynamic> toJson() => {
    'dataPoints': dataPoints.map((p) => p.toJson()).toList(),
  };
}

/// Generic Metric wrapper – only one of [sum], [gauge] etc. is populated.
class Metric {
  Metric({
    required this.name,
    this.unit,
    this.description,
    this.sum,
    this.gauge,
    // extend later: histogram, exponentialHistogram, summary …
  });

  final String name;
  final String? unit;
  final String? description;
  final Sum? sum;
  final Gauge? gauge;

  // Returns the most-recent datapoint (max timeUnixNano).
  num? latestValueOf() {
    final points = (sum?.dataPoints ?? gauge?.dataPoints);
    if (points == null || points.isEmpty) return null;
    points.sort((a, b) => b.timeUnixNano.compareTo(a.timeUnixNano));
    return points.first.value;
  }

  num sumOfPoints() {
    final points = (sum?.dataPoints ?? gauge?.dataPoints);
    if (points == null || points.isEmpty) return 0;
    num c = 0;

    for (final p in points) {
      c += p.value;
    }
    return c;
  }

  factory Metric.fromJson(Map<String, dynamic> j) => Metric(
    name: j['name'] ?? '',
    unit: j['unit'],
    description: j['description'],
    sum: j['sum'] != null ? Sum.fromJson(j['sum']) : null,
    gauge: j['gauge'] != null ? Gauge.fromJson(j['gauge']) : null,
  );

  Map<String, dynamic> toJson() => {
    'name': name,
    if (unit != null) 'unit': unit,
    if (description != null) 'description': description,
    if (sum != null) 'sum': sum!.toJson(),
    if (gauge != null) 'gauge': gauge!.toJson(),
  };
}

/* ───────── Wrapper layers (ScopeMetrics, ResourceMetrics, Export) ───────── */

class ScopeMetrics {
  ScopeMetrics({required this.scope, required this.metrics});
  final Scope scope;
  final List<Metric> metrics;

  factory ScopeMetrics.fromJson(Map<String, dynamic> j) => ScopeMetrics(
    scope: Scope.fromJson(j['scope'] ?? const {}),
    metrics: (j['metrics'] as List<dynamic>? ?? [])
        .cast<Map<String, dynamic>>()
        .map(Metric.fromJson)
        .toList(),
  );

  Map<String, dynamic> toJson() => {
    'scope': scope.toJson(),
    'metrics': metrics.map((m) => m.toJson()).toList(),
  };
}

class ResourceMetrics {
  ResourceMetrics({required this.resource, required this.scopeMetrics});
  final Resource resource;
  final List<ScopeMetrics> scopeMetrics;

  factory ResourceMetrics.fromJson(Map<String, dynamic> j) => ResourceMetrics(
    resource: Resource.fromJson(j['resource'] ?? const {}),
    scopeMetrics: (j['scopeMetrics'] as List<dynamic>? ?? [])
        .cast<Map<String, dynamic>>()
        .map(ScopeMetrics.fromJson)
        .toList(),
  );

  Map<String, dynamic> toJson() => {
    'resource': resource.toJson(),
    'scopeMetrics': scopeMetrics.map((s) => s.toJson()).toList(),
  };
}

class OtlpMetricExport {
  OtlpMetricExport({required this.resourceMetrics});
  final List<ResourceMetrics> resourceMetrics;

  /// Convenience factory – supply either raw JSON string or already-decoded map.
  factory OtlpMetricExport.fromJsonString(String jsonStr) =>
      OtlpMetricExport.fromJson(json.decode(jsonStr) as Map<String, dynamic>);

  factory OtlpMetricExport.fromJson(Map<String, dynamic> j) => OtlpMetricExport(
    resourceMetrics:
        (j['resourceMetrics'] as List<dynamic>? ??
                // Some collectors emit *just* one ResourceMetric object.
                (j.containsKey('resource') ? [j] : []))
            .cast<Map<String, dynamic>>()
            .map(ResourceMetrics.fromJson)
            .toList(),
  );

  Map<String, dynamic> toJson() => {
    'resourceMetrics': resourceMetrics.map((r) => r.toJson()).toList(),
  };

  /// Flatten everything into a single list of metrics.
  List<Metric> allMetrics() => [
    for (final rm in resourceMetrics)
      for (final sm in rm.scopeMetrics) ...sm.metrics,
  ];
}
