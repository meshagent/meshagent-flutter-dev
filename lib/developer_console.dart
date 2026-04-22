import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:meshagent/meshagent.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import 'containers.dart';
import 'terminal.dart';
import 'trace_viewer.dart';

class RoomDeveloperLogsScope extends InheritedNotifier<ValueNotifier<int>> {
  const RoomDeveloperLogsScope({
    super.key,
    required this.events,
    required ValueNotifier<int> version,
    required super.child,
  }) : super(notifier: version);

  final List<RoomEvent> events;

  ValueNotifier<int> get version => notifier!;

  static RoomDeveloperLogsScope? maybeOf(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<RoomDeveloperLogsScope>();
  }
}

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
  late final events = widget.events;
  late final ValueNotifier<int> _eventVersion = ValueNotifier<int>(0);
  late StreamSubscription<RoomLogEvent> sub;

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

  void onRoomEvent(RoomEvent event) {
    if (!mounted) return;

    events.add(event);
    _eventVersion.value++;
  }

  @override
  void dispose() {
    sub.cancel();
    _eventVersion.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RoomDeveloperLogsScope(
      events: events,
      version: _eventVersion,
      child: widget.child,
    );
  }
}

enum DeveloperConsoleView {
  logs,
  traces,
  metrics,
  terminal,
  containers,
  images,
  services,
}

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
  DeveloperConsoleView view = DeveloperConsoleView.logs;
  String logFilter = "";
  String traceFilter = "";
  LogLevelFilter logLevelFilter = LogLevelFilter.all;
  int logClearSignal = 0;
  bool adding = false;

  ExecSession? selectedRun;
  final List<ExecSession> runs = [];
  final ValueNotifier<int> _localDeveloperLogVersion = ValueNotifier<int>(0);
  StreamSubscription<RoomLogEvent>? developerLogsSubscription;
  RoomClient? _developerLogsRoom;

  @override
  void initState() {
    super.initState();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _syncDeveloperLogsSource();
  }

  @override
  void didUpdateWidget(covariant RoomDeveloperConsole oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.room != widget.room ||
        !identical(oldWidget.events, widget.events)) {
      _syncDeveloperLogsSource();
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

  RoomDeveloperLogsScope? _developerLogsScope() {
    final scope = RoomDeveloperLogsScope.maybeOf(context);
    if (scope == null || !identical(scope.events, widget.events)) {
      return null;
    }
    return scope;
  }

  void _cancelDeveloperLogsSubscription() {
    developerLogsSubscription?.cancel();
    developerLogsSubscription = null;
    _developerLogsRoom = null;
  }

  void _syncDeveloperLogsSource() {
    final scope = _developerLogsScope();
    if (scope != null) {
      _cancelDeveloperLogsSubscription();
      return;
    }

    if (developerLogsSubscription != null &&
        identical(_developerLogsRoom, widget.room)) {
      return;
    }

    _cancelDeveloperLogsSubscription();
    _developerLogsRoom = widget.room;
    developerLogsSubscription = widget.room.developer.logs().listen((event) {
      widget.events.add(event);
      _localDeveloperLogVersion.value++;
    }, onError: _handleDeveloperLogError);
  }

  Listenable _developerLogsListenable() {
    return _developerLogsScope()?.version ?? _localDeveloperLogVersion;
  }

  @override
  void dispose() {
    _cancelDeveloperLogsSubscription();
    _localDeveloperLogVersion.dispose();
    super.dispose();
  }

  void onRun(ExecSession run) {
    if (!mounted) return;

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
      if (nextView != DeveloperConsoleView.traces) {
        traceFilter = "";
      }
    });
  }

  double _contrastRatio(Color a, Color b) {
    final lighter = max(a.computeLuminance(), b.computeLuminance());
    final darker = min(a.computeLuminance(), b.computeLuminance());
    return (lighter + 0.05) / (darker + 0.05);
  }

  Color _defaultSelectedTabForeground(
    ShadColorScheme colorScheme,
    Color backgroundColor,
  ) {
    final foregroundContrast = _contrastRatio(
      colorScheme.foreground,
      backgroundColor,
    );
    final backgroundContrast = _contrastRatio(
      colorScheme.background,
      backgroundColor,
    );
    return foregroundContrast >= backgroundContrast
        ? colorScheme.foreground
        : colorScheme.background;
  }

  Widget _tabLabel(String label, DeveloperConsoleView tabView) {
    final theme = ShadTheme.of(context);
    final tabsTheme = theme.tabsTheme;
    final selected = view == tabView;
    final selectedBackgroundColor =
        tabsTheme.tabSelectedBackgroundColor ?? theme.colorScheme.background;
    final color = selected
        ? tabsTheme.tabSelectedForegroundColor ??
              tabsTheme.tabForegroundColor ??
              _defaultSelectedTabForeground(
                theme.colorScheme,
                selectedBackgroundColor,
              )
        : tabsTheme.tabForegroundColor ?? theme.colorScheme.primary;

    return Text(
      label,
      style: TextStyle(color: color, fontWeight: .w600),
    );
  }

  Widget terminalView(BuildContext context) {
    return Row(
      children: [
        SizedBox(
          width: 300,
          child: ListView(
            padding: .symmetric(horizontal: 20, vertical: 8),
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
                            final launchOptions = await promptForImageTerminal(
                              context,
                              initialCommand: "bash -l",
                              initialRoomMounts: [
                                RoomStorageMountSpec(
                                  path: "/data",
                                  readOnly: false,
                                ),
                              ],
                            );
                            if (launchOptions == null) {
                              return;
                            }
                            setState(() {
                              adding = true;
                            });
                            try {
                              final roomToken = widget.room.protocol.token;
                              if (roomToken == null || roomToken.isEmpty) {
                                throw StateError("room token unavailable");
                              }
                              final containerId = await widget.room.containers
                                  .run(
                                    image: widget.shellImage,
                                    command: "sleep infinity",
                                    mounts: launchOptions.mounts,
                                    writableRootFs: true,
                                    env: {
                                      "OPENAI_API_KEY": roomToken,
                                      "MESHAGENT_TOKEN": roomToken,
                                    },
                                    private: true,
                                  );

                              final run = widget.room.containers.exec(
                                containerId: containerId,
                                command: launchOptions.command,
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
    final theme = ShadTheme.of(context);
    final cs = theme.colorScheme;
    final developerLogsListenable = _developerLogsListenable();

    return ColoredBox(
      color: cs.card,
      child: Column(
        crossAxisAlignment: .stretch,
        children: [
          Padding(
            padding: EdgeInsets.only(top: 20, bottom: 8, left: 20),
            child: Row(
              mainAxisSize: .max,
              crossAxisAlignment: .start,
              children: [
                SizedBox(
                  width: 300,
                  child: ShadTabs<DeveloperConsoleView>(
                    value: view,
                    onChanged: _setView,
                    tabs: [
                      ShadTab(value: .logs, child: _tabLabel("Logs", .logs)),
                      ShadTab(
                        value: .traces,
                        child: _tabLabel("Traces", .traces),
                      ),
                      ShadTab(
                        value: .metrics,
                        child: _tabLabel("Metrics", .metrics),
                      ),
                    ],
                  ),
                ),
                SizedBox(width: 15),
                SizedBox(
                  width: 560,
                  child: ShadTabs<DeveloperConsoleView>(
                    value: view,
                    onChanged: _setView,
                    tabs: [
                      ShadTab(
                        value: .containers,
                        child: _tabLabel("Containers", .containers),
                      ),
                      ShadTab(
                        value: .images,
                        child: _tabLabel("Images", .images),
                      ),
                      ShadTab(
                        value: .services,
                        child: _tabLabel("Services", .services),
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
                        value: .terminal,
                        child: _tabLabel("Terminal", .terminal),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          if (view == DeveloperConsoleView.logs ||
              view == DeveloperConsoleView.traces)
            Padding(
              padding: EdgeInsets.only(bottom: 10, left: 20, right: 20),
              child: Row(
                children: [
                  SizedBox(
                    width: 420,
                    child: ShadInput(
                      placeholder: Text(
                        view == DeveloperConsoleView.traces
                            ? "Filter traces..."
                            : "Filter...",
                      ),
                      onChanged: (value) {
                        setState(() {
                          if (view == DeveloperConsoleView.traces) {
                            traceFilter = value;
                          } else {
                            logFilter = value;
                          }
                        });
                      },
                    ),
                  ),
                  if (view == DeveloperConsoleView.logs) SizedBox(width: 10),
                  if (view == DeveloperConsoleView.logs)
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
                  if (view == DeveloperConsoleView.logs) SizedBox(width: 10),
                  if (view == DeveloperConsoleView.logs)
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
              DeveloperConsoleView.traces ||
              DeveloperConsoleView.logs ||
              DeveloperConsoleView.metrics => ListenableBuilder(
                listenable: developerLogsListenable,
                builder: (context, child) => switch (view) {
                  DeveloperConsoleView.traces => LiveTraceViewer(
                    events: widget.events,
                    searchQuery: traceFilter,
                  ),
                  DeveloperConsoleView.logs => LiveLogViewer(
                    events: widget.events,
                    searchQuery: logFilter,
                    levelFilter: logLevelFilter,
                    clearSignal: logClearSignal,
                  ),
                  DeveloperConsoleView.metrics => LiveMetricsViewer(
                    pricing: widget.pricing,
                    events: widget.events,
                  ),
                  _ => SizedBox.shrink(),
                },
              ),
              DeveloperConsoleView.terminal => terminalView(context),
              DeveloperConsoleView.images => Column(
                crossAxisAlignment: .stretch,
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
  late final events = widget.events;
  StreamSubscription? sub;

  final columnNames = ["Event", "Description"];
  final verticalScrollController = ScrollController();

  @override
  void initState() {
    super.initState();

    sub = widget.client?.listen(onRoomEvent);
  }

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

  @override
  Widget build(BuildContext context) {
    final theme = ShadTheme.of(context);
    final cardTheme = theme.cardTheme;

    return LayoutBuilder(
      builder: (context, constraints) => Column(
        children: [
          Container(
            clipBehavior: Clip.hardEdge,
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(color: cardTheme.border!.bottom!.color!),
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
