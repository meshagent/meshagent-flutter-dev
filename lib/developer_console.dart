import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:meshagent/meshagent.dart';
import 'package:meshagent_flutter_widgets/widgets.dart';
import 'package:meshagent_luau/meshagent_luau.dart';
import 'package:shadcn_ui/shadcn_ui.dart';
import 'package:super_sliver_list/super_sliver_list.dart';
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
  services,
  widgets,
  images,
}

DeveloperConsoleView view = DeveloperConsoleView.traces;

class RoomDeveloperConsole extends StatefulWidget {
  const RoomDeveloperConsole({
    super.key,
    required this.events,
    required this.room,
    required this.pricing,
    required this.shellImage,
  });

  final String shellImage;
  final Map<String, dynamic>? pricing;
  final RoomClient room;
  final List<RoomEvent> events;

  @override
  State createState() => _RoomDeveloperConsoleState();
}

class _RoomDeveloperConsoleState extends State<RoomDeveloperConsole> {
  var view = DeveloperConsoleView.logs;

  ExecSession? selectedRun;
  final List<ExecSession> runs = [];

  void onRun(ExecSession run) {
    if (!mounted) {
      return;
    }
    setState(() {
      runs.add(run);
      view = DeveloperConsoleView.terminal;
      selectedRun = run;
    });
  }

  bool adding = false;

  Widget terminalView(BuildContext context) {
    return Row(
      children: [
        SizedBox(
          width: 300,
          child: ListView(
            padding: EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            children: [
              Row(
                children: [
                  ShadButton.secondary(
                    leading: adding
                        ? SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(),
                          )
                        : Icon(LucideIcons.plus),
                    onPressed: adding
                        ? null
                        : () async {
                            setState(() {
                              adding = true;
                            });
                            try {
                              final containerId = await widget.room.containers
                                  .run(
                                    image: widget.shellImage,
                                    command: "sleep infinity",
                                    mountPath: "/data",
                                    writableRootFs: true,
                                    env: {
                                      "OPENAI_API_KEY":
                                          (widget.room.protocol.channel
                                                  as WebSocketProtocolChannel)
                                              .jwt,
                                      "MESHAGENT_TOKEN":
                                          (widget.room.protocol.channel
                                                  as WebSocketProtocolChannel)
                                              .jwt,
                                    },
                                    private: true,
                                  );

                              final run = widget.room.containers.exec(
                                containerId: containerId,
                                command: "bash -l",
                                tty: true,
                              );
                              if (!mounted) {
                                return;
                              }
                              setState(() {
                                runs.add(run);
                                selectedRun = run;
                              });
                            } on RoomServerException catch (err) {
                              showShadDialog(
                                context: context,
                                builder: (context) => ShadDialog.alert(
                                  title: Text("Unable to run container"),
                                  description: Text("$err"),
                                ),
                              );
                            } finally {
                              if (mounted) {
                                setState(() {
                                  adding = false;
                                });
                              }
                            }
                          },
                    child: Text("Add Terminal"),
                  ),
                  Spacer(),
                ],
              ),
              for (final run in runs)
                Row(
                  spacing: 8,
                  children: [
                    Expanded(
                      child: Padding(
                        padding: EdgeInsets.only(top: 8),
                        child:
                            (selectedRun == run
                            ? ShadButton.secondary
                            : ShadButton.ghost)(
                              onPressed: () {
                                setState(() {
                                  selectedRun = run;
                                });
                              },
                              child: Text(run.command),
                            ),
                      ),
                    ),
                    Padding(
                      padding: EdgeInsets.only(top: 8),
                      child: ShadButton.ghost(
                        onPressed: () {
                          setState(() {
                            run.stop();
                            runs.remove(run);
                          });
                        },
                        child: Icon(LucideIcons.x),
                      ),
                    ),
                  ],
                ),
            ],
          ),
        ),

        Expanded(
          child: selectedRun != null
              ? ContainerTerminal(
                  key: ObjectKey(selectedRun),
                  session: selectedRun!,
                )
              : Container(),
        ),
      ],
    );
  }

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
                      value: DeveloperConsoleView.widgets,
                      child: Text("Widgets"),
                    ),
                  ],
                ),
              ),

              SizedBox(width: 15),
              SizedBox(
                width: 420,
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
                      value: DeveloperConsoleView.services,
                      child: Text("Services"),
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
            DeveloperConsoleView.terminal => terminalView(context),

            DeveloperConsoleView.images => Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: EdgeInsetsGeometry.symmetric(horizontal: 20),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      ShadButton.ghost(
                        trailing: Icon(LucideIcons.download),
                        onPressed: () async {
                          await showShadDialog(
                            context: context,
                            builder: (context) => PullImage(room: widget.room),
                          );
                        },
                        child: Text("Pull Image"),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: ImageTable(client: widget.room, onRun: onRun),
                ),
              ],
            ),
            DeveloperConsoleView.containers => ContainerTable(
              client: widget.room,
              onRun: onRun,
            ),
            DeveloperConsoleView.services => ServiceTable(
              client: widget.room,
            ),

            DeveloperConsoleView.widgets => LuauConsoleViewer(),
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
      verticalScrollController.jumpTo(
        verticalScrollController.position.maxScrollExtent,
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
      builder: (context, constraints) => Column(
        children: [
          Container(
            clipBehavior: Clip.hardEdge,
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(
                  color: ShadTheme.of(context).cardTheme.border!.bottom!.color!,
                ),
              ),
            ),
            height: min(50, constraints.maxHeight),
            child: ShadTable(
              rowCount: 0,
              columnCount: 2,
              pinnedRowCount: 1,
              columnSpanExtent: (column) =>
                  column == 0 ? FixedSpanExtent(200) : RemainingSpanExtent(),
              header: (context, column) => ShadTableCell.header(
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
            child: (events.isEmpty)
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
                        verticalScrollController: verticalScrollController,
                        rowCount: events.length,
                        columnCount: 2,
                        pinnedRowCount: 0,
                        columnSpanExtent: (column) => column == 0
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
                                              events[viscinity.row].description,
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

class LuauConsoleViewer extends StatefulWidget {
  LuauConsoleViewer({super.key});

  @override
  State createState() => _LuauConsoleViewer();
}

class _LuauConsoleViewer extends State<LuauConsoleViewer> {
  final scrollController = ScrollController();
  @override
  Widget build(BuildContext context) {
    final console = LuauConsole.of(context);

    if (console.consoleEntries.length == 0) {
      return SizedBox();
    }

    return SelectionArea(
      child: SuperListView(
        controller: scrollController,
        padding: const EdgeInsets.all(20.0),
        children: [
          for (final entry in console.consoleEntries)
            Text(
              "${entry.scriptName}:${entry.lineNumber}: ${entry.spans.join("\n")}",
              style: entry.type == ConsoleEntryType.error
                  ? GoogleFonts.sourceCodePro(color: Colors.red)
                  : GoogleFonts.sourceCodePro(),
            ),
        ],
      ),
    );
  }
}
