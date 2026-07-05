import 'dart:async';
import 'dart:convert';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:libghostty/libghostty.dart' as ghostty;
import 'package:meshagent/meshagent.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

Future<void>? _terminalRuntimeInitialization;

Future<void> initializeMeshagentTerminalRuntime({Uri? wasmUri}) {
  return _terminalRuntimeInitialization ??= ghostty.initializeForWeb(
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
       _onResize = onResize,
       _terminal = ghostty.Terminal(cols: cols, rows: rows) {
    _cols = cols;
    _rows = rows;
    _terminal.onWritePty = (data) {
      _onOutput?.call(utf8.decode(data, allowMalformed: true));
    };
    _terminal.addListener(notifyListeners);
  }

  final void Function(String data)? _onOutput;
  final void Function(int width, int height, int pixelWidth, int pixelHeight)?
  _onResize;
  final ghostty.Terminal _terminal;
  late int _cols;
  late int _rows;
  bool _showCursor = true;

  ghostty.Terminal get rawTerminal => _terminal;
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
    if (data.isEmpty) {
      return;
    }
    _onOutput?.call(data);
  }

  void resizeToLayout({
    required Size size,
    required double cellWidth,
    required double cellHeight,
  }) {
    final cols = (size.width / cellWidth).floor().clamp(1, 1000);
    final rows = (size.height / cellHeight).floor().clamp(1, 1000);
    if (cols == _cols && rows == _rows) {
      return;
    }
    _cols = cols;
    _rows = rows;
    _terminal.resize(
      cols: cols,
      rows: rows,
      cellWidthPx: cellWidth.round(),
      cellHeightPx: cellHeight.round(),
    );
    _onResize?.call(cols, rows, size.width.round(), size.height.round());
  }

  void scrollViewport(int delta) {
    _terminal.scrollViewport(delta);
    notifyListeners();
  }

  void setCursorVisibleMode(bool visible) {
    if (_showCursor == visible) {
      return;
    }
    _showCursor = visible;
    notifyListeners();
  }

  void clearSelection() {
    _terminal.selection = null;
  }

  String? selectedText() {
    return _terminal.formatSelection();
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

  final FocusNode _focusNode = FocusNode();
  final ghostty.RenderState _renderState = ghostty.RenderState();
  final ghostty.RowIterator _rows = ghostty.RowIterator();
  final ghostty.CellIterator _cells = ghostty.CellIterator();
  ghostty.Position? _selectionAnchor;
  bool _selecting = false;

  @override
  void initState() {
    super.initState();
    widget.terminal.addListener(_handleTerminalChange);
  }

  @override
  void didUpdateWidget(MeshagentTerminalView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(widget.terminal, oldWidget.terminal)) {
      oldWidget.terminal.removeListener(_handleTerminalChange);
      _selectionAnchor = null;
      widget.terminal.addListener(_handleTerminalChange);
    }
  }

  @override
  void dispose() {
    widget.terminal.removeListener(_handleTerminalChange);
    _focusNode.dispose();
    _cells.dispose();
    _rows.dispose();
    _renderState.dispose();
    super.dispose();
  }

  void _handleTerminalChange() {
    if (mounted) {
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final foreground = widget.muted
        ? _terminalForeground.withAlpha(170)
        : _terminalForeground;
    final textStyle = GoogleFonts.sourceCodePro(
      fontWeight: FontWeight.w500,
      color: foreground,
      fontSize: _terminalFontSize,
    );
    final metrics = _measureMetrics(textStyle);

    return LayoutBuilder(
      builder: (context, constraints) {
        final terminalSize = Size(
          (constraints.maxWidth - widget.padding.horizontal).clamp(
            1.0,
            double.infinity,
          ),
          (constraints.maxHeight - widget.padding.vertical).clamp(
            1.0,
            double.infinity,
          ),
        );
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) {
            return;
          }
          widget.terminal.resizeToLayout(
            size: terminalSize,
            cellWidth: metrics.cellSize.width,
            cellHeight: metrics.cellSize.height,
          );
        });

        return Focus(
          focusNode: _focusNode,
          autofocus: true,
          onKeyEvent: (node, event) {
            if (event is! KeyDownEvent) {
              return KeyEventResult.ignored;
            }
            if (_copySelectionShortcut(event)) {
              return KeyEventResult.handled;
            }
            final encoded = _encodeKey(event);
            if (encoded == null) {
              return KeyEventResult.ignored;
            }
            widget.terminal.sendInput(encoded);
            return KeyEventResult.handled;
          },
          child: Listener(
            onPointerDown: (event) {
              if ((event.buttons & kPrimaryMouseButton) == 0) {
                return;
              }
              _selecting = true;
              _focusNode.requestFocus();
              _startSelection(event.localPosition, metrics.cellSize);
            },
            onPointerMove: (event) {
              if (!_selecting || (event.buttons & kPrimaryMouseButton) == 0) {
                return;
              }
              _updateSelection(event.localPosition, metrics.cellSize);
            },
            onPointerUp: (event) {
              if (!_selecting) {
                return;
              }
              _selecting = false;
            },
            onPointerCancel: (event) {
              if (!_selecting) {
                return;
              }
              _selecting = false;
            },
            onPointerSignal: (event) {
              if (event is PointerScrollEvent) {
                widget.terminal.scrollViewport(
                  event.scrollDelta.dy > 0 ? 3 : -3,
                );
              }
            },
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => _focusNode.requestFocus(),
              child: ColoredBox(
                color: _terminalBackground,
                child: Padding(
                  padding: widget.padding,
                  child: MouseRegion(
                    cursor: SystemMouseCursors.text,
                    child: CustomPaint(
                      painter: _GhosttyTerminalPainter(
                        terminal: widget.terminal,
                        renderState: _renderState,
                        rows: _rows,
                        cells: _cells,
                        textStyle: textStyle,
                        foreground: foreground,
                        background: _terminalBackground,
                        selectionColor: _terminalSelection,
                        metrics: metrics,
                        showCursor:
                            widget.showCursor && widget.terminal.showCursor,
                      ),
                      size: Size.infinite,
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  _TerminalTextMetrics _measureMetrics(TextStyle style) {
    final painter = TextPainter(
      text: TextSpan(text: "M", style: style),
      textDirection: TextDirection.ltr,
    )..layout();
    final lineMetrics = painter.computeLineMetrics().single;
    final cellSize = Size(painter.width, painter.height);
    return _TerminalTextMetrics(
      cellSize: cellSize,
      baseline: lineMetrics.baseline,
    );
  }

  String? _encodeKey(KeyDownEvent event) {
    final key = event.logicalKey;
    final isControl = HardwareKeyboard.instance.isControlPressed;
    final isMeta = HardwareKeyboard.instance.isMetaPressed;
    final isAlt = HardwareKeyboard.instance.isAltPressed;

    if (key == LogicalKeyboardKey.enter ||
        key == LogicalKeyboardKey.numpadEnter) {
      return "\r";
    }
    if (key == LogicalKeyboardKey.backspace) {
      return "\x7f";
    }
    if (key == LogicalKeyboardKey.tab) {
      return "\t";
    }
    if (key == LogicalKeyboardKey.escape) {
      return "\x1b";
    }
    if (key == LogicalKeyboardKey.arrowUp) {
      return "\x1b[A";
    }
    if (key == LogicalKeyboardKey.arrowDown) {
      return "\x1b[B";
    }
    if (key == LogicalKeyboardKey.arrowRight) {
      return "\x1b[C";
    }
    if (key == LogicalKeyboardKey.arrowLeft) {
      return "\x1b[D";
    }
    if (key == LogicalKeyboardKey.delete) {
      return "\x1b[3~";
    }
    if (key == LogicalKeyboardKey.home) {
      return "\x1b[H";
    }
    if (key == LogicalKeyboardKey.end) {
      return "\x1b[F";
    }
    if (key == LogicalKeyboardKey.pageUp) {
      return "\x1b[5~";
    }
    if (key == LogicalKeyboardKey.pageDown) {
      return "\x1b[6~";
    }

    final character = event.character;
    if (isControl && !isMeta && character != null && character.length == 1) {
      final code = character.toUpperCase().codeUnitAt(0);
      if (code >= 0x40 && code <= 0x5f) {
        return String.fromCharCode(code - 0x40);
      }
    }
    if (!isControl && !isMeta && !isAlt && character != null) {
      return character;
    }
    return null;
  }

  bool _copySelectionShortcut(KeyDownEvent event) {
    if (event.logicalKey != LogicalKeyboardKey.keyC) {
      return false;
    }
    final isCopyModifier =
        HardwareKeyboard.instance.isMetaPressed ||
        HardwareKeyboard.instance.isControlPressed;
    if (!isCopyModifier) {
      return false;
    }
    final selectedText = widget.terminal.selectedText();
    if (selectedText == null || selectedText.isEmpty) {
      return false;
    }
    Clipboard.setData(ClipboardData(text: selectedText));
    return true;
  }

  void _startSelection(Offset position, Size cellSize) {
    _selectionAnchor = _positionFromOffset(position, cellSize);
    widget.terminal.clearSelection();
  }

  void _updateSelection(Offset position, Size cellSize) {
    final anchor = _selectionAnchor;
    if (anchor == null) {
      return;
    }
    final end = _positionFromOffset(position, cellSize);
    final startRef = ghostty.GridRef.at(
      widget.terminal.rawTerminal,
      anchor,
      pointTag: ghostty.PointTag.viewport,
    );
    final endRef = ghostty.GridRef.at(
      widget.terminal.rawTerminal,
      end,
      pointTag: ghostty.PointTag.viewport,
    );
    widget.terminal.rawTerminal.selection = ghostty.Selection.fromRefs(
      start: startRef,
      end: endRef,
    );
  }

  ghostty.Position _positionFromOffset(Offset position, Size cellSize) {
    final terminalPosition = Offset(
      position.dx - widget.padding.left,
      position.dy - widget.padding.top,
    );
    final col = (terminalPosition.dx / cellSize.width)
        .floor()
        .clamp(0, widget.terminal.cols - 1)
        .toInt();
    final row = (terminalPosition.dy / cellSize.height)
        .floor()
        .clamp(0, widget.terminal.rows - 1)
        .toInt();
    return ghostty.Position(row: row, col: col);
  }
}

class _TerminalTextMetrics {
  const _TerminalTextMetrics({required this.cellSize, required this.baseline});

  final Size cellSize;
  final double baseline;
}

class _GhosttyTerminalPainter extends CustomPainter {
  _GhosttyTerminalPainter({
    required this.terminal,
    required this.renderState,
    required this.rows,
    required this.cells,
    required this.textStyle,
    required this.foreground,
    required this.background,
    required this.selectionColor,
    required this.metrics,
    required this.showCursor,
  });

  final MeshagentTerminalController terminal;
  final ghostty.RenderState renderState;
  final ghostty.RowIterator rows;
  final ghostty.CellIterator cells;
  final TextStyle textStyle;
  final Color foreground;
  final Color background;
  final Color selectionColor;
  final _TerminalTextMetrics metrics;
  final bool showCursor;

  @override
  void paint(Canvas canvas, Size size) {
    renderState.update(terminal.rawTerminal);
    final cellSize = metrics.cellSize;
    canvas.drawRect(Offset.zero & size, Paint()..color = background);
    rows.reset(renderState);
    while (rows.next()) {
      cells.reset(rows);
      while (cells.next()) {
        if (cells.wide == ghostty.CellWidth.spacerTail) {
          continue;
        }
        final origin = Offset(
          cells.col * cellSize.width,
          rows.index * cellSize.height,
        );
        final background = cells.backgroundArgb;
        if (background != null) {
          canvas.drawRect(
            origin & Size(cellSize.width, cellSize.height),
            Paint()..color = Color(background),
          );
        }
        if (cells.isSelected) {
          canvas.drawRect(
            origin & Size(cellSize.width, cellSize.height),
            Paint()..color = selectionColor,
          );
        }
        if (!cells.hasText || cells.style.invisible) {
          continue;
        }
        final style = cells.style;
        final painter = TextPainter(
          text: TextSpan(
            text: cells.content,
            style: textStyle.copyWith(
              color: cells.isSelected
                  ? Colors.white
                  : _cellColor(cells.foregroundArgb) ?? foreground,
              fontWeight: style.bold ? FontWeight.w700 : textStyle.fontWeight,
              fontStyle: style.italic ? FontStyle.italic : FontStyle.normal,
              decoration: style.strikethrough
                  ? TextDecoration.lineThrough
                  : TextDecoration.none,
            ),
          ),
          textDirection: TextDirection.ltr,
        )..layout();
        final textOffset = origin.translate(
          0,
          metrics.baseline - painter.computeLineMetrics().single.baseline,
        );
        painter.paint(canvas, textOffset);
      }
      rows.dirty = false;
    }
    _paintCursor(canvas);
    renderState.dirty = ghostty.DirtyState.clean;
  }

  void _paintCursor(Canvas canvas) {
    if (!showCursor) {
      return;
    }
    final cursor = renderState.cursor;
    if (!cursor.visible) {
      return;
    }
    final origin = Offset(
      cursor.position.col * metrics.cellSize.width,
      cursor.position.row * metrics.cellSize.height,
    );
    final rect = origin & Size(metrics.cellSize.width, metrics.cellSize.height);
    final paint = Paint()..color = _cursorColor();
    switch (cursor.shape) {
      case ghostty.CursorShape.bar:
        canvas.drawRect(
          Rect.fromLTWH(rect.left, rect.top, 2, rect.height),
          paint,
        );
      case ghostty.CursorShape.underline:
        canvas.drawRect(
          Rect.fromLTWH(rect.left, rect.bottom - 2, rect.width, 2),
          paint,
        );
      case ghostty.CursorShape.block:
      case ghostty.CursorShape.blockHollow:
        canvas.drawRect(rect, paint);
    }
  }

  Color _cursorColor() {
    final color = renderState.colors.cursor;
    if (color == null) {
      return foreground;
    }
    return Color(color.toArgb32);
  }

  Color? _cellColor(int? argb) => argb == null ? null : Color(argb);

  @override
  bool shouldRepaint(covariant _GhosttyTerminalPainter oldDelegate) {
    return true;
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
