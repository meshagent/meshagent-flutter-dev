import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:meshagent/meshagent.dart';
import 'package:shadcn_ui/shadcn_ui.dart';
import 'package:xterm/xterm.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

class RoomTerminal extends StatefulWidget {
  const RoomTerminal({super.key, required this.client});

  final RoomClient client;

  @override
  State createState() => _RoomTerminal();
}

class _RoomTerminal extends State<RoomTerminal> {
  @override
  void initState() {
    super.initState();
    terminal = Terminal(
      onOutput: (data) {
        websocket.sink.add(Uint8List.fromList([0, ...utf8.encode(data)]));
      },
      onResize: onResize,
    );

    final protocol = widget.client.protocol.channel as WebSocketProtocolChannel;
    final url = protocol.url;
    final jwt = protocol.jwt;

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

  late final Terminal terminal;

  void onResize(int width, int height, _, __) {
    final data = utf8.encode(jsonEncode({"Height": height, "Width": width}));
    websocket.sink.add(Uint8List.fromList([4, ...data]));
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
        return TerminalView(
          terminal,
          textStyle: TerminalStyle(
            fontFamily: GoogleFonts.sourceCodePro(
              fontWeight: FontWeight.w500,
            ).fontFamily!,
            fontSize: 15,
          ),
          padding: EdgeInsets.all(16),
        );
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
  @override
  void initState() {
    super.initState();
    terminal = Terminal(
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
    subStdout.cancel();
  }

  void watch() {
    subStdout = widget.session.output.listen(onData);
  }

  void onData(data) {
    if (data is Uint8List) {
      final text = utf8.decode(data);
      terminal.write(text);
    }
  }

  late final StreamSubscription subStdout;

  late final Terminal terminal;

  void onResize(int width, int height, _, __) {
    if (!widget.session.closed) {
      widget.session.resize(width: width, height: height).catchError((err) {});
    }
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
        return TerminalView(
          terminal,
          textStyle: TerminalStyle(
            fontFamily: GoogleFonts.sourceCodePro(
              fontWeight: FontWeight.w500,
              color: closed
                  ? ShadTheme.of(context).colorScheme.foreground.withAlpha(100)
                  : ShadTheme.of(context).colorScheme.foreground,
            ).fontFamily!,
            fontSize: 15,
          ),
          padding: EdgeInsets.all(16),
        );
      },
    );
  }
}
