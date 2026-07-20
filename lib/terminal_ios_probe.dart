import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:meshagent/meshagent.dart';

Future<void> initializeMeshagentTerminalRuntime({Uri? wasmUri}) async {}

class RoomTerminal extends StatelessWidget {
  const RoomTerminal({super.key, required this.client});

  final RoomClient client;

  @override
  Widget build(BuildContext context) {
    return const Center(child: Text("Terminal is disabled for this iOS build"));
  }
}

class MeshagentTerminalController extends ChangeNotifier {
  MeshagentTerminalController({
    void Function(String data)? onOutput,
    void Function(int width, int height, int pixelWidth, int pixelHeight)?
    onResize,
    int cols = 120,
    int rows = 32,
  }) : _onOutput = onOutput,
       _cols = cols,
       _rows = rows;

  final void Function(String data)? _onOutput;
  final StringBuffer _buffer = StringBuffer();
  final int _cols;
  final int _rows;
  bool _showCursor = true;

  int get cols => _cols;
  int get rows => _rows;
  bool get showCursor => _showCursor;
  String get text => _buffer.toString();

  void write(String text) {
    _buffer.write(text);
    notifyListeners();
  }

  void writeBytes(Uint8List data) {
    write(utf8.decode(data, allowMalformed: true));
  }

  void sendInput(String data) {
    _onOutput?.call(data);
  }

  void setCursorVisibleMode(bool visible) {
    if (_showCursor == visible) {
      return;
    }
    _showCursor = visible;
    notifyListeners();
  }

  void clearSelection() {}

  String selectedText() {
    return "";
  }
}

class MeshagentTerminalView extends StatefulWidget {
  const MeshagentTerminalView({
    super.key,
    required this.terminal,
    this.muted = false,
    this.showCursor = true,
    this.padding = const EdgeInsets.all(16),
  });

  final MeshagentTerminalController terminal;
  final bool muted;
  final bool showCursor;
  final EdgeInsets padding;

  @override
  State<MeshagentTerminalView> createState() => _MeshagentTerminalViewState();
}

class _MeshagentTerminalViewState extends State<MeshagentTerminalView> {
  final _scrollController = ScrollController();
  final _inputController = TextEditingController();

  @override
  void initState() {
    super.initState();
    widget.terminal.addListener(_scrollToBottom);
  }

  @override
  void didUpdateWidget(MeshagentTerminalView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.terminal == widget.terminal) {
      return;
    }
    oldWidget.terminal.removeListener(_scrollToBottom);
    widget.terminal.addListener(_scrollToBottom);
  }

  @override
  void dispose() {
    widget.terminal.removeListener(_scrollToBottom);
    _scrollController.dispose();
    _inputController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) {
        return;
      }
      _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
    });
  }

  void _submit(String value) {
    if (value.isEmpty) {
      return;
    }
    widget.terminal.sendInput("$value\n");
    _inputController.clear();
  }

  @override
  Widget build(BuildContext context) {
    const background = Color(0xff0c0c0c);
    final foreground = widget.muted
        ? const Color(0xfff2f2f2).withAlpha(170)
        : const Color(0xfff2f2f2);
    final textStyle = TextStyle(
      color: foreground,
      fontFamily: "monospace",
      fontSize: 15,
      fontWeight: FontWeight.w500,
    );

    return ColoredBox(
      color: background,
      child: Padding(
        padding: widget.padding,
        child: Column(
          children: [
            Expanded(
              child: AnimatedBuilder(
                animation: widget.terminal,
                builder: (context, _) {
                  return SingleChildScrollView(
                    controller: _scrollController,
                    child: Align(
                      alignment: Alignment.topLeft,
                      child: SelectableText(
                        widget.terminal.text,
                        style: textStyle,
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _inputController,
              enabled: !widget.muted,
              style: textStyle,
              cursorColor: foreground,
              decoration: InputDecoration(
                isDense: true,
                hintText: "Command",
                hintStyle: textStyle.copyWith(color: foreground.withAlpha(120)),
                border: const OutlineInputBorder(),
              ),
              onSubmitted: _submit,
            ),
          ],
        ),
      ),
    );
  }
}

class ContainerTerminal extends StatefulWidget {
  const ContainerTerminal({super.key, required this.session});

  final ExecSession session;

  @override
  State createState() => _ContainerTerminal();
}

class _ContainerTerminal extends State<ContainerTerminal> {
  final _decoder = const Utf8Decoder(allowMalformed: true);
  late final MeshagentTerminalController terminal;
  late final StreamSubscription subStdout;
  Object? error;
  bool closed = false;

  @override
  void initState() {
    super.initState();
    terminal = MeshagentTerminalController(
      onOutput: (data) {
        widget.session.write(utf8.encode(data));
      },
    );
    for (final line in widget.session.previousOutput) {
      terminal.write(_decoder.convert(line));
    }
    subStdout = widget.session.output.listen(
      (data) {
        terminal.write(_decoder.convert(data));
      },
      onError: (e, st) {
        debugPrint("terminal output decode error: $e");
      },
      cancelOnError: false,
    );
    widget.session.result
        .then((_) {
          if (mounted) {
            setState(() {
              closed = true;
            });
          }
        })
        .catchError((e) {
          if (mounted) {
            setState(() {
              closed = true;
              error = e;
            });
          }
        });
  }

  @override
  void dispose() {
    terminal.dispose();
    subStdout.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (closed && error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text("Terminal Session Ended"),
            Text("$error", style: const TextStyle(color: Colors.red)),
          ],
        ),
      );
    }
    return MeshagentTerminalView(terminal: terminal, muted: closed);
  }
}
