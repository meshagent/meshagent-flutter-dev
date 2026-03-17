import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:meshagent/meshagent.dart';
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
  void _handleLogError(Object error, StackTrace stackTrace) {
    FlutterError.reportError(
      FlutterErrorDetails(
        exception: error,
        stack: stackTrace,
        library: "meshagent_flutter_dev",
        context: ErrorDescription("while listening to developer logs"),
      ),
    );
  }

  @override
  void initState() {
    super.initState();

    sub = widget.client.developer.logs().listen(
      onRoomEvent,
      onError: _handleLogError,
    );
  }

  late StreamSubscription<RoomLogEvent> sub;

  late final events = widget.events;

  void onRoomEvent(RoomEvent event) {
    if (!mounted) return;

    events.add(event);
  }

  @override
  void dispose() {
    super.dispose();

    sub.cancel();
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
  static const _consoleBackground = Color(0xFF222222);
  static const _consoleSurface = Color(0xFF2A2A2A);
  static const _consoleBorder = Color(0xFF383838);
  static const _consoleSelectedSurface = Color(0xFFF5F5F5);
  static const _consoleText = Color(0xFFF5F5F5);
  static const _consoleMutedText = Color(0xFFD0D0D0);

  var view = DeveloperConsoleView.logs;
  String logFilter = "";
  LogLevelFilter logLevelFilter = LogLevelFilter.all;
  int logClearSignal = 0;

  ExecSession? selectedRun;
  final List<ExecSession> runs = [];
  StreamSubscription<RoomLogEvent>? developerLogsSubscription;

  @override
  void initState() {
    super.initState();
    _subscribeToDeveloperLogs();
  }

  @override
  void didUpdateWidget(covariant RoomDeveloperConsole oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.room != widget.room) {
      developerLogsSubscription?.cancel();
      developerLogsSubscription = null;
      _subscribeToDeveloperLogs();
    }
  }

  void _handleDeveloperLogError(Object error, StackTrace stackTrace) {
    FlutterError.reportError(
      FlutterErrorDetails(
        exception: error,
        stack: stackTrace,
        library: "meshagent_flutter_dev",
        context: ErrorDescription("while listening to developer logs"),
      ),
    );
  }

  void _subscribeToDeveloperLogs() {
    developerLogsSubscription = widget.room.developer.logs().listen((event) {
      if (!mounted) {
        return;
      }
      setState(() {
        widget.events.add(event);
      });
    }, onError: _handleDeveloperLogError);
  }

  @override
  void dispose() {
    developerLogsSubscription?.cancel();
    super.dispose();
  }

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

  void _setView(DeveloperConsoleView nextView) {
    setState(() {
      view = nextView;
      if (nextView != DeveloperConsoleView.logs) {
        logFilter = "";
        logLevelFilter = LogLevelFilter.all;
      }
    });
  }

  bool adding = false;

  Widget _tabLabel(String label, DeveloperConsoleView tabView) {
    final selected = view == tabView;
    return Text(
      label,
      style: TextStyle(
        color: selected ? _consoleBackground : _consoleText,
        fontWeight: FontWeight.w600,
      ),
    );
  }

  ShadThemeData _consoleTheme(BuildContext context) {
    final base = ShadTheme.of(context);
    final consoleTextTheme = base.textTheme
        .apply(bodyColor: _consoleText, displayColor: _consoleText)
        .copyWith(
          small: base.textTheme.small.copyWith(color: _consoleText),
          p: base.textTheme.p.copyWith(color: _consoleText),
          large: base.textTheme.large.copyWith(color: _consoleText),
          muted: base.textTheme.muted.copyWith(color: _consoleMutedText),
          table: base.textTheme.table.copyWith(color: _consoleText),
        );
    return base.copyWith(
      colorScheme: base.colorScheme.copyWith(
        background: _consoleBackground,
        foreground: _consoleText,
        card: _consoleSurface,
        cardForeground: _consoleText,
        popover: _consoleSurface,
        popoverForeground: _consoleText,
        primary: _consoleText,
        primaryForeground: _consoleBackground,
        secondary: _consoleSurface,
        secondaryForeground: _consoleText,
        muted: _consoleSurface,
        mutedForeground: _consoleMutedText,
        accent: _consoleSurface,
        accentForeground: _consoleText,
        destructive: _consoleText,
        destructiveForeground: _consoleBackground,
        border: _consoleBorder,
        input: _consoleSurface,
        ring: _consoleMutedText,
        selection: _consoleBorder,
      ),
      textTheme: consoleTextTheme,
      decoration: ShadDecoration(
        color: _consoleBackground,
        border: ShadBorder.all(color: _consoleBorder, width: 1),
      ),
      popoverTheme: ShadPopoverTheme(
        decoration: ShadDecoration(
          color: _consoleSurface,
          border: ShadBorder.all(color: _consoleBorder, width: 1),
        ),
      ),
      tabsTheme: base.tabsTheme.copyWith(
        decoration: ShadDecoration(
          color: _consoleSurface,
          border: ShadBorder.all(color: _consoleBorder, width: 1),
        ),
        tabBackgroundColor: _consoleSurface,
        tabForegroundColor: _consoleText,
        tabSelectedBackgroundColor: _consoleSelectedSurface,
        tabSelectedForegroundColor: _consoleBackground,
        tabTextStyle: base.tabsTheme.tabTextStyle,
        tabSelectedHoverBackgroundColor: const Color(0xFFEFEFEF),
        tabHoverBackgroundColor: _consoleBorder,
        tabHoverForegroundColor: _consoleText,
      ),
      ghostButtonTheme: base.ghostButtonTheme.copyWith(
        foregroundColor: _consoleText,
        hoverForegroundColor: _consoleText,
        hoverBackgroundColor: _consoleSurface,
      ),
      secondaryButtonTheme: base.secondaryButtonTheme.copyWith(
        backgroundColor: _consoleSurface,
        foregroundColor: _consoleText,
        decoration: ShadDecoration(
          color: _consoleSurface,
          border: ShadBorder.all(color: _consoleBorder, width: 1),
        ),
      ),
      outlineButtonTheme: base.outlineButtonTheme.copyWith(
        backgroundColor: _consoleSurface,
        foregroundColor: _consoleText,
        hoverForegroundColor: _consoleText,
        decoration: ShadDecoration(
          color: _consoleSurface,
          border: ShadBorder.all(color: _consoleBorder, width: 1),
        ),
      ),
      inputTheme: base.inputTheme.copyWith(
        style: base.inputTheme.style?.copyWith(color: _consoleText),
        placeholderStyle: base.inputTheme.placeholderStyle?.copyWith(
          color: _consoleMutedText,
        ),
        decoration: ShadDecoration(
          color: _consoleSurface,
          border: ShadBorder.all(color: _consoleBorder, width: 1),
          focusedBorder: ShadBorder.all(color: _consoleMutedText, width: 1),
        ),
      ),
      selectTheme: base.selectTheme.copyWith(
        decoration: ShadDecoration(
          color: _consoleSurface,
          border: ShadBorder.all(color: _consoleBorder, width: 1),
          focusedBorder: ShadBorder.all(color: _consoleMutedText, width: 1),
        ),
        placeholderStyle: base.selectTheme.placeholderStyle?.copyWith(
          color: _consoleMutedText,
        ),
      ),
      optionTheme: base.optionTheme.copyWith(
        backgroundColor: _consoleSurface,
        hoveredBackgroundColor: _consoleBorder,
        selectedBackgroundColor: _consoleBackground,
        selectedIconColor: _consoleText,
        textStyle: (base.optionTheme.textStyle ?? const TextStyle()).copyWith(
          color: _consoleText,
        ),
        selectedTextStyle:
            (base.optionTheme.selectedTextStyle ?? const TextStyle()).copyWith(
              color: _consoleText,
            ),
      ),
      checkboxTheme: base.checkboxTheme.copyWith(
        color: _consoleText,
        decoration: ShadDecoration(
          color: _consoleSurface,
          border: ShadBorder.all(color: _consoleMutedText, width: 1),
          focusedBorder: ShadBorder.all(color: _consoleText, width: 1),
        ),
      ),
    );
  }

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
    final materialBase = Theme.of(context);
    final consoleMaterialTheme = materialBase.copyWith(
      brightness: Brightness.dark,
      scaffoldBackgroundColor: _consoleBackground,
      canvasColor: _consoleBackground,
      cardColor: _consoleSurface,
      dividerColor: _consoleBorder,
      iconTheme: const IconThemeData(color: _consoleText),
      textTheme: materialBase.textTheme.apply(
        bodyColor: _consoleText,
        displayColor: _consoleText,
      ),
      dataTableTheme: DataTableThemeData(
        headingTextStyle:
            (materialBase.textTheme.titleSmall ?? const TextStyle()).copyWith(
              color: _consoleText,
              fontWeight: FontWeight.w600,
            ),
        dataTextStyle: (materialBase.textTheme.bodyMedium ?? const TextStyle())
            .copyWith(color: _consoleText),
        dividerThickness: 1,
        headingRowColor: const WidgetStatePropertyAll(_consoleBackground),
        dataRowColor: const WidgetStatePropertyAll(Colors.transparent),
      ),
    );
    return ShadTheme(
      data: _consoleTheme(context),
      child: Theme(
        data: consoleMaterialTheme,
        child: ColoredBox(
          color: _consoleBackground,
          child: Column(
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
                        onChanged: _setView,
                        tabs: [
                          ShadTab(
                            value: DeveloperConsoleView.logs,
                            child: _tabLabel("Logs", DeveloperConsoleView.logs),
                          ),
                          ShadTab(
                            value: DeveloperConsoleView.traces,
                            child: _tabLabel(
                              "Traces",
                              DeveloperConsoleView.traces,
                            ),
                          ),
                          ShadTab(
                            value: DeveloperConsoleView.metrics,
                            child: _tabLabel(
                              "Metrics",
                              DeveloperConsoleView.metrics,
                            ),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(width: 15),
                    SizedBox(
                      width: 420,
                      child: ShadTabs<DeveloperConsoleView>(
                        value: view,
                        onChanged: _setView,
                        tabs: [
                          ShadTab(
                            value: DeveloperConsoleView.images,
                            child: _tabLabel(
                              "Images",
                              DeveloperConsoleView.images,
                            ),
                          ),
                          ShadTab(
                            value: DeveloperConsoleView.containers,
                            child: _tabLabel(
                              "Containers",
                              DeveloperConsoleView.containers,
                            ),
                          ),
                          ShadTab(
                            value: DeveloperConsoleView.services,
                            child: _tabLabel(
                              "Services",
                              DeveloperConsoleView.services,
                            ),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(width: 15),
                    SizedBox(
                      width: 100,
                      child: ShadTabs<DeveloperConsoleView>(
                        value: view,
                        onChanged: _setView,
                        tabs: [
                          ShadTab(
                            value: DeveloperConsoleView.terminal,
                            child: _tabLabel(
                              "Terminal",
                              DeveloperConsoleView.terminal,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              if (view == DeveloperConsoleView.logs)
                Padding(
                  padding: EdgeInsets.only(bottom: 10, left: 20, right: 20),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 420,
                        child: ShadInput(
                          placeholder: Text("Filter..."),
                          onChanged: (value) {
                            setState(() {
                              logFilter = value;
                            });
                          },
                        ),
                      ),
                      SizedBox(width: 10),
                      SizedBox(
                        width: 180,
                        child: ShadSelect<LogLevelFilter>(
                          initialValue: logLevelFilter,
                          onChanged: (value) {
                            setState(() {
                              logLevelFilter = value ?? LogLevelFilter.all;
                            });
                          },
                          selectedOptionBuilder: (context, value) =>
                              Text(logLevelFilterLabel(value)),
                          options: [
                            for (final level in LogLevelFilter.values)
                              ShadOption<LogLevelFilter>(
                                value: level,
                                child: Text(logLevelFilterLabel(level)),
                              ),
                          ],
                        ),
                      ),
                      SizedBox(width: 10),
                      ShadButton.ghost(
                        leading: Icon(LucideIcons.trash, size: 16),
                        onPressed: () {
                          setState(() {
                            widget.events.removeWhere(
                              (event) =>
                                  event is RoomLogEvent &&
                                  event.name == "otel.log",
                            );
                            logClearSignal++;
                          });
                        },
                        child: Text("Clear Logs"),
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
                    searchQuery: logFilter,
                    levelFilter: logLevelFilter,
                    clearSignal: logClearSignal,
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
                                  builder: (context) =>
                                      PullImage(room: widget.room),
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
                },
              ),
            ],
          ),
        ),
      ),
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
