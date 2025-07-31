import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:meshagent/room_server_client.dart';
import 'package:shadcn_ui/shadcn_ui.dart';
import './terminal.dart';
import "./trace_viewer.dart";
import 'package:stream_transform/stream_transform.dart';
import 'package:flutter/services.dart';
import './containers.dart';

class RoomDeveloperLogsListener extends StatefulWidget {
  const RoomDeveloperLogsListener({
    super.key,
    required this.events,
    required this.client,
    required this.child,
  });

  final List<RoomEvent> events;
  final RoomClient client;
  final Widget child;

  @override
  State createState() => _RoomDeveloperLogsListenerState();
}

class _RoomDeveloperLogsListenerState extends State<RoomDeveloperLogsListener> {
  @override
  void initState() {
    super.initState();

    widget.client.developer.enable();

    sub = widget.client.listen(onRoomEvent);
  }

  late StreamSubscription sub;

  late final events = widget.events;

  void onRoomEvent(RoomEvent event) {
    if (!mounted) return;

    events.add(event);
  }

  @override
  void dispose() {
    super.dispose();

    sub.cancel();

    widget.client.developer.disable();
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}

enum DeveloperConsoleView {
  logs,
  traces,
  metrics,
  terminal,
  containers,
  images,
  builds,
}

DeveloperConsoleView view = DeveloperConsoleView.traces;

class RoomDeveloperConsole extends StatefulWidget {
  const RoomDeveloperConsole({
    super.key,
    required this.events,
    required this.room,
    required this.pricing,
  });

  final Map<String, dynamic>? pricing;
  final RoomClient room;
  final List<RoomEvent> events;

  @override
  State createState() => _RoomDeveloperConsoleState();
}

class _RoomDeveloperConsoleState extends State<RoomDeveloperConsole> {
  var view = DeveloperConsoleView.logs;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: EdgeInsets.only(top: 20, bottom: 8, left: 20),
          child: Row(
            mainAxisSize: MainAxisSize.max,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 300,
                child: ShadTabs<DeveloperConsoleView>(
                  value: view,
                  onChanged: (value) {
                    setState(() {
                      view = value;
                    });
                  },
                  tabs: [
                    ShadTab(
                      value: DeveloperConsoleView.logs,
                      child: Text("Logs"),
                    ),
                    ShadTab(
                      value: DeveloperConsoleView.traces,
                      child: Text("Traces"),
                    ),
                    ShadTab(
                      value: DeveloperConsoleView.metrics,
                      child: Text("Metrics"),
                    ),
                  ],
                ),
              ),

              SizedBox(width: 15),

              SizedBox(
                width: 500,
                child: ShadTabs<DeveloperConsoleView>(
                  value: view,
                  onChanged: (value) {
                    setState(() {
                      view = value;
                    });
                  },
                  tabs: [
                    ShadTab(
                      value: DeveloperConsoleView.images,
                      child: Text("Images"),
                    ),
                    ShadTab(
                      value: DeveloperConsoleView.containers,
                      child: Text("Containers"),
                    ),
                    ShadTab(
                      value: DeveloperConsoleView.builds,
                      child: Text("Builds"),
                    ),
                  ],
                ),
              ),

              SizedBox(width: 15),

              SizedBox(
                width: 100,
                child: ShadTabs<DeveloperConsoleView>(
                  value: view,
                  onChanged: (value) {
                    setState(() {
                      view = value;
                    });
                  },
                  tabs: [
                    ShadTab(
                      value: DeveloperConsoleView.terminal,
                      child: Text("Terminal"),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        Expanded(
          child: switch (view) {
            DeveloperConsoleView.traces => LiveTraceViewer(
              events: Stream.fromIterable(
                widget.events,
              ).followedBy(widget.room.events),
            ),
            DeveloperConsoleView.logs => LiveLogViewer(
              events: Stream.fromIterable(
                widget.events,
              ).followedBy(widget.room.events),
            ),
            DeveloperConsoleView.metrics => LiveMetricsViewer(
              pricing: widget.pricing,
              events: Stream.fromIterable(
                widget.events,
              ).followedBy(widget.room.events),
            ),
            DeveloperConsoleView.terminal => RoomTerminal(client: widget.room),

            DeveloperConsoleView.images => ImageTable(client: widget.room),
            DeveloperConsoleView.containers => ContainerTable(
              client: widget.room,
            ),
            DeveloperConsoleView.builds => BuildTable(client: widget.room),
          },
        ),
      ],
    );
  }
}

class LiveLogsViewer extends StatefulWidget {
  const LiveLogsViewer({super.key, required this.events, required this.client});

  final RoomClient? client;
  final List<RoomEvent> events;

  @override
  State createState() => _LiveLogsViewerState();
}

class _LiveLogsViewerState extends State<LiveLogsViewer> {
  @override
  void initState() {
    super.initState();
    sub = widget.client?.listen(onRoomEvent);
  }

  StreamSubscription? sub;

  late final events = widget.events;

  void onRoomEvent(RoomEvent event) {
    if (!mounted) return;

    setState(() {});

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;

      verticalScrollController.animateTo(
        verticalScrollController.position.maxScrollExtent,
        duration: Duration(milliseconds: 200),
        curve: Curves.linear,
      );
    });
  }

  @override
  void dispose() {
    super.dispose();
    verticalScrollController.dispose();

    sub?.cancel();
  }

  final columnNames = ["Event", "Description"];

  ScrollController verticalScrollController = ScrollController();

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder:
          (context, constraints) => Column(
            children: [
              Container(
                clipBehavior: Clip.hardEdge,
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(
                      color:
                          ShadTheme.of(context).cardTheme.border!.bottom.color,
                    ),
                  ),
                ),
                height: min(50, constraints.maxHeight),
                child: ShadTable(
                  rowCount: 0,
                  columnCount: 2,
                  pinnedRowCount: 1,
                  columnSpanExtent:
                      (column) =>
                          column == 0
                              ? FixedSpanExtent(200)
                              : RemainingSpanExtent(),
                  header:
                      (context, column) => ShadTableCell.header(
                        child: Text(
                          columnNames[column],
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                  builder: (context, viscinity) {
                    if (viscinity.column == 0) {
                      return ShadTableCell(
                        child: Text(
                          events[viscinity.row].name,
                          overflow: TextOverflow.ellipsis,
                        ),
                      );
                    } else {
                      return ShadTableCell(
                        child: Text(
                          events[viscinity.row].description,
                          overflow: TextOverflow.ellipsis,
                        ),
                      );
                    }
                  },
                ),
              ),
              Expanded(
                child:
                    (events.isEmpty)
                        ? SizedBox()
                        : ScrollbarTheme(
                          data: ScrollbarThemeData(
                            crossAxisMargin: 5,
                            mainAxisMargin: 5,
                          ),
                          child: Scrollbar(
                            trackVisibility: false,
                            thumbVisibility: true,
                            controller: verticalScrollController,
                            scrollbarOrientation: ScrollbarOrientation.right,
                            child: ShadTable(
                              verticalScrollController:
                                  verticalScrollController,
                              rowCount: events.length,
                              columnCount: 2,
                              pinnedRowCount: 0,
                              columnSpanExtent:
                                  (column) =>
                                      column == 0
                                          ? FixedSpanExtent(200)
                                          : RemainingSpanExtent(),
                              builder: (context, viscinity) {
                                if (viscinity.column == 0) {
                                  return ShadTableCell(
                                    child: Text(
                                      events[viscinity.row].name,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  );
                                } else {
                                  return ShadTableCell(
                                    child: ShadContextMenuRegion(
                                      items: [
                                        ShadContextMenuItem(
                                          onPressed: () {
                                            Clipboard.setData(
                                              ClipboardData(
                                                text:
                                                    events[viscinity.row]
                                                        .description,
                                              ),
                                            );
                                          },
                                          child: Text("Copy Description"),
                                        ),
                                      ],
                                      child: Text(
                                        events[viscinity.row].description,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  );
                                }
                              },
                            ),
                          ),
                        ),
              ),
            ],
          ),
    );
  }
}
