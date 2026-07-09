import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flterm/flterm.dart' as flterm;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:meshagent/meshagent.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

Future<void>? _terminalRuntimeInitialization;

Future<void> initializeMeshagentTerminalRuntime({Uri? wasmUri}) {
  return _terminalRuntimeInitialization ??= flterm.initializeForWeb(
    wasmUri ??
        Uri.parse(
          "assets/packages/meshagent_flutter_dev/assets/libghostty.wasm",
        ),
  );
}

class _ResizeForwarder {
  _ResizeForwarder({required void Function(int width, int height) onSend})
    : _onSend = onSend;

  final void Function(int width, int height) _onSend;
  Timer? _timer;
  int? _pendingWidth;
  int? _pendingHeight;
  int? _sentWidth;
  int? _sentHeight;

  void queue(int width, int height) {
    if (_pendingWidth == width && _pendingHeight == height) {
      return;
    }
    _pendingWidth = width;
    _pendingHeight = height;
    _timer ??= Timer(const Duration(milliseconds: 16), _flush);
  }

  void _flush() {
    _timer = null;
    final width = _pendingWidth;
    final height = _pendingHeight;
    if (width == null || height == null) {
      return;
    }
    if (_sentWidth == width && _sentHeight == height) {
      return;
    }
    _sentWidth = width;
    _sentHeight = height;
    _onSend(width, height);
  }

  void dispose() {
    _timer?.cancel();
    _timer = null;
  }
}

class RoomTerminal extends StatefulWidget {
  const RoomTerminal({super.key, required this.client});

  final RoomClient client;

  @override
  State createState() => _RoomTerminal();
}

class MeshagentTerminalController extends ChangeNotifier {
  MeshagentTerminalController({
    void Function(String data)? onOutput,
    void Function(int width, int height, int pixelWidth, int pixelHeight)?
    onResize,
    int cols = 120,
    int rows = 32,
  }) : _onOutput = onOutput,
       _onResize = onResize {
    _cols = cols;
    _rows = rows;
    _terminal = flterm.TerminalController(
      config: flterm.TerminalConfig(cols: cols, rows: rows),
    );
    _terminal.onOutput = (data) {
      _onOutput?.call(utf8.decode(data, allowMalformed: true));
    };
    _terminal.onResize = (cols, rows) {
      _cols = cols;
      _rows = rows;
      _onResize?.call(cols, rows, 0, 0);
    };
    _terminal.addListener(notifyListeners);
  }

  final void Function(String data)? _onOutput;
  final void Function(int width, int height, int pixelWidth, int pixelHeight)?
  _onResize;
  late final flterm.TerminalController _terminal;
  late int _cols;
  late int _rows;
  bool _showCursor = true;

  flterm.TerminalController get rawTerminal => _terminal;
  int get cols => _cols;
  int get rows => _rows;
  bool get showCursor => _showCursor;

  void write(String text) {
    writeBytes(Uint8List.fromList(utf8.encode(text)));
  }

  void writeBytes(Uint8List data) {
    _terminal.write(data);
  }

  void sendInput(String data) {
    _terminal.sendText(data);
  }

  void setCursorVisibleMode(bool visible) {
    if (_showCursor == visible) {
      return;
    }
    _showCursor = visible;
    notifyListeners();
  }

  void clearSelection() {
    _terminal.clearSelection();
  }

  String selectedText() {
    return _terminal.selectedText();
  }

  @override
  void dispose() {
    _terminal.removeListener(notifyListeners);
    _terminal.dispose();
    super.dispose();
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
  static const _terminalBackground = Color(0xff0c0c0c);
  static const _terminalForeground = Color(0xfff2f2f2);
  static const _terminalSelection = Color(0xff2f5f9f);
  static const _terminalFontSize = 15.0;

  late final Future<TextStyle> _terminalTextStyle = _loadTerminalTextStyle();

  @override
  Widget build(BuildContext context) {
    final foreground = widget.muted
        ? _terminalForeground.withAlpha(170)
        : _terminalForeground;

    return FutureBuilder<TextStyle>(
      future: _terminalTextStyle,
      builder: (context, snapshot) {
        final textStyle = snapshot.data;
        if (textStyle == null) {
          return const ColoredBox(color: _terminalBackground);
        }
        return _buildTerminal(foreground: foreground, textStyle: textStyle);
      },
    );
  }

  Future<TextStyle> _loadTerminalTextStyle() async {
    final textStyle = GoogleFonts.sourceCodePro(
      fontSize: _terminalFontSize,
      fontWeight: FontWeight.w500,
    );
    await GoogleFonts.pendingFonts();
    return textStyle;
  }

  Widget _buildTerminal({
    required Color foreground,
    required TextStyle textStyle,
  }) {
    return flterm.TerminalView(
      controller: widget.terminal.rawTerminal,
      autofocus: true,
      padding: widget.padding,
      theme: flterm.TerminalTheme.dark().copyWith(
        palette: flterm.ColorPalette(
          ansiColors: flterm.TerminalTheme.dark().palette.ansiColors,
          background: _terminalBackground,
          foreground: foreground,
        ),
        cursor: flterm.CursorTheme(
          opacity: widget.showCursor && widget.terminal.showCursor ? 1.0 : 0.0,
        ),
        fontFamily: textStyle.fontFamily ?? "Source Code Pro",
        fontFamilyFallback:
            textStyle.fontFamilyFallback ?? const ["Source Code Pro"],
        fontSize: _terminalFontSize,
        fontWeight: textStyle.fontWeight ?? FontWeight.w500,
        selection: const flterm.SelectionTheme(
          background: flterm.DynamicColor.fixed(_terminalSelection),
          foreground: flterm.DynamicColor.fixed(Colors.white),
        ),
      ),
    );
  }
}

class _RoomTerminal extends State<RoomTerminal> {
  late final _ResizeForwarder _resizeForwarder;

  @override
  void initState() {
    super.initState();
    _resizeForwarder = _ResizeForwarder(
      onSend: (width, height) {
        final data = utf8.encode(
          jsonEncode({"Height": height, "Width": width}),
        );
        websocket.sink.add(Uint8List.fromList([4, ...data]));
      },
    );
    terminal = MeshagentTerminalController(
      onOutput: (data) {
        websocket.sink.add(Uint8List.fromList([0, ...utf8.encode(data)]));
      },
      onResize: onResize,
    );

    final url = widget.client.protocol.url;
    final jwt = widget.client.protocol.token;
    if (url == null || jwt == null || jwt.isEmpty) {
      throw StateError(
        "room protocol does not expose a websocket url and token",
      );
    }

    final execUrl = url.replace(
      path: "${url.path}/exec",
      queryParameters: {
        "token": jwt,
        "tty": "true",
        "room_storage_path": "/data",
      },
    );

    websocket = WebSocketChannel.connect(execUrl);
    websocket.sink.done.then((_) {
      if (mounted) {
        setState(() {
          closed = true;
        });
      }
    });
    watch(websocket);
  }

  bool connecting = true;
  bool closed = false;

  @override
  void dispose() {
    super.dispose();
    _resizeForwarder.dispose();
    terminal.dispose();
    sub.cancel();
    websocket.sink.close();
  }

  void watch(WebSocketChannel websocket) {
    sub = websocket.stream.listen(onData);
  }

  void onData(data) {
    if (mounted) {
      setState(() {
        connecting = false;
      });
    }
    if (data is Uint8List) {
      final text = utf8.decode(Uint8List.sublistView(data, 1));
      terminal.write(text);
    }
  }

  late final StreamSubscription sub;
  late final WebSocketChannel websocket;

  late final MeshagentTerminalController terminal;

  void onResize(int width, int height, _, __) {
    _resizeForwarder.queue(width, height);
  }

  int width = 0;
  int height = 0;

  @override
  Widget build(BuildContext context) {
    if (closed) {
      return Center(child: Text("Terminal Session Ended"));
    }
    if (connecting) {
      return Center(
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(width: 16, height: 16, child: CircularProgressIndicator()),
            SizedBox(width: 10),
            Text("Terminal Session Connecting..."),
          ],
        ),
      );
    }
    return LayoutBuilder(
      builder: (context, constraints) {
        return MeshagentTerminalView(terminal: terminal);
      },
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
  late final _ResizeForwarder _resizeForwarder;

  @override
  void initState() {
    super.initState();
    _resizeForwarder = _ResizeForwarder(
      onSend: (width, height) {
        if (!widget.session.closed) {
          unawaited(
            widget.session
                .resize(width: width, height: height)
                .catchError((Object _) {}),
          );
        }
      },
    );
    terminal = MeshagentTerminalController(
      onOutput: (data) {
        widget.session.write(utf8.encode(data));
      },
      onResize: onResize,
    );
    for (final line in widget.session.previousOutput) {
      final text = utf8.decode(line);
      terminal.write(text);
    }

    watch();

    widget.session.result
        .then((result) {
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

  Object? error;
  bool closed = false;

  @override
  void dispose() {
    super.dispose();
    _resizeForwarder.dispose();
    terminal.dispose();
    subStdout.cancel();
  }

  void watch() {
    subStdout = widget.session.output.listen(
      onData,
      onError: (e, st) {
        // log it, but don't lose the terminal
        debugPrint("terminal output decode error: $e");
      },
      cancelOnError: false,
    );
  }

  final _decoder = const Utf8Decoder(allowMalformed: true);

  void onData(Uint8List data) {
    final text = _decoder.convert(data);
    terminal.write(text);
  }

  late final StreamSubscription subStdout;

  late final MeshagentTerminalController terminal;

  void onResize(int width, int height, _, __) {
    _resizeForwarder.queue(width, height);
  }

  int width = 0;
  int height = 0;

  @override
  Widget build(BuildContext context) {
    if (closed) {
      if (error != null) {
        return Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text("Terminal Session Ended"),

              Text("${error}", style: TextStyle(color: Colors.red)),
            ],
          ),
        );
      }
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        return MeshagentTerminalView(terminal: terminal, muted: closed);
      },
    );
  }
}
