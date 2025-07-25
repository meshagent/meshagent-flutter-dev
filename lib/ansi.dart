import 'package:flutter/widgets.dart';

/// Converts a string that contains ANSI/ASCII escape codes (SGR sequences)
/// into a [TextSpan].  Only the most frequently‑used codes are handled
/// (colors, bold, italic, underline, reset).  Unknown codes are ignored.
///
/// Example:
/// ```dart
/// RichText(
///   text: ansiToTextSpan('\x1B[31mHello \x1B[1;34mWorld\x1B[0m!'),
/// )
/// ```

TextSpan ansiToTextSpan(String source, {TextStyle? baseStyle}) {
  // 1⃣  Remove cursor‑movement / clear‑screen sequences we can’t show.
  source = _stripNonSgrCsi(source);

  // 2⃣  Parse the remaining SGR codes exactly as before.
  final sgr = RegExp(r'(\x1B|\u001B)\[([0-9;]*)m');

  final List<InlineSpan> spans = [];
  TextStyle current = baseStyle ?? const TextStyle();
  int last = 0;

  for (final m in sgr.allMatches(source)) {
    if (m.start > last) {
      spans.add(
        TextSpan(text: source.substring(last, m.start), style: current),
      );
    }

    final params =
        m[2]!.isEmpty
            ? <int>[0]
            : m[2]!
                .split(';')
                .where((s) => s.isNotEmpty)
                .map(int.parse)
                .toList();
    _applySgr(params, (t) => current = t(current)); // mutates `current`

    last = m.end;
  }
  if (last < source.length) {
    spans.add(TextSpan(text: source.substring(last), style: current));
  }

  return TextSpan(style: baseStyle, children: spans);
}

String _killSpinnerFrames(String s) {
  // Matches one printable char (no ESC, no CR/LF) between the two CSI pairs
  final spinner = RegExp(r'\x1B\[1G\x1B\[0K[^\x1B\r\n]\x1B\[1G\x1B\[0K');
  return s.replaceAll(spinner, '');
}

/// Remove any CSI whose final byte *isn’t* “m” (graphics).
String _stripNonSgrCsi(String s) {
  s = _killSpinnerFrames(s);
  // 1⃣  CSI that isn’t SGR (“m”)
  final nonSgrCsi = RegExp(r'\x1B\[[0-9;?]*[ -/]*[@A-LN-Z\\^_`{|}~]');
  s = s.replaceAll(nonSgrCsi, '');

  // 2⃣  OSC (␛ ] …), DCS (␛ P …), SOS/PM/APC (␛ X/^/_ …)
  //     Terminates with BEL (␇) **or** ST (␛ \).
  final oscLike = RegExp(r'\x1B[][PX^_].*?(?:\x07|\x1B\\)', dotAll: true);
  return s.replaceAll(oscLike, '');
}

/// Mutates the current [TextStyle] according to SGR parameters.
void _applySgr(List<int> p, void Function(TextStyle Function(TextStyle)) set) {
  var i = 0;

  while (i < p.length) {
    final v = p[i];
    switch (v) {
      case 0:
        set((_) => const TextStyle());
        break;
      case 1:
        set((s) => s.merge(const TextStyle(fontWeight: FontWeight.bold)));
        break;
      case 3:
        set((s) => s.merge(const TextStyle(fontStyle: FontStyle.italic)));
        break;
      case 4:
        set(
          (s) => s.merge(const TextStyle(decoration: TextDecoration.underline)),
        );
        break;
      case 22:
        set((s) => s.merge(const TextStyle(fontWeight: FontWeight.normal)));
        break;
      case 23:
        set((s) => s.merge(const TextStyle(fontStyle: FontStyle.normal)));
        break;
      case 24:
        set((s) => s.merge(const TextStyle(decoration: TextDecoration.none)));
        break;

      // ----- 16‑colour foreground -----
      case >= 30 && <= 37:
        set((s) => s.merge(TextStyle(color: _ansi16Color(v - 30, false))));
        break;
      case >= 90 && <= 97:
        set((s) => s.merge(TextStyle(color: _ansi16Color(v - 90, true))));
        break;

      // ----- 16‑colour background -----
      case >= 40 && <= 47:
        set(
          (s) =>
              s.merge(TextStyle(backgroundColor: _ansi16Color(v - 40, false))),
        );
        break;
      case >= 100 && <= 107:
        set(
          (s) =>
              s.merge(TextStyle(backgroundColor: _ansi16Color(v - 100, true))),
        );
        break;

      // ----- 256 / true‑colour foreground -----
      case 38:
        if (i + 1 < p.length) {
          if (p[i + 1] == 5 && i + 2 < p.length) {
            set((s) => s.merge(TextStyle(color: _ansi256Color(p[i + 2]))));
            i += 2;
          } else if (p[i + 1] == 2 && i + 4 < p.length) {
            set(
              (s) => s.merge(
                TextStyle(
                  color: Color.fromARGB(0xFF, p[i + 2], p[i + 3], p[i + 4]),
                ),
              ),
            );
            i += 4;
          }
        }
        break;

      // ----- 256 / true‑colour background -----
      case 48:
        if (i + 1 < p.length) {
          if (p[i + 1] == 5 && i + 2 < p.length) {
            set(
              (s) =>
                  s.merge(TextStyle(backgroundColor: _ansi256Color(p[i + 2]))),
            );
            i += 2;
          } else if (p[i + 1] == 2 && i + 4 < p.length) {
            set(
              (s) => s.merge(
                TextStyle(
                  backgroundColor: Color.fromARGB(
                    0xFF,
                    p[i + 2],
                    p[i + 3],
                    p[i + 4],
                  ),
                ),
              ),
            );
            i += 4;
          }
        }
        break;
    }
    i++;
  }
}

/// Maps the 16 basic ANSI colors (0–7) plus their bright variants.
Color _ansi16Color(int idx, bool bright) {
  final theme = TerminalColorTheme.materialDark;
  // Base palette (dark): black, red, green, yellow, blue, magenta, cyan, white

  if (bright) {
    idx += 8;
  }

  return theme.palette[idx]!;
}

/// 256‑color lookup: converts xterm 0‑255 index into RGB.
Color _ansi256Color(int n) {
  // 0‑15 are the same 16‑color palette already handled; produce a rough mapping.
  if (n < 16) return _ansi16Color(n & 7, n >= 8);

  // 16‑231 form a 6×6×6 color cube.
  if (n >= 16 && n <= 231) {
    final c = n - 16;
    final r = (c ~/ 36) % 6;
    final g = (c ~/ 6) % 6;
    final b = c % 6;
    int tone(int v) => v == 0 ? 0 : 55 + (v * 40);
    return Color.fromARGB(0xFF, tone(r), tone(g), tone(b));
  }

  // 232‑255 are grayscale (24 steps).
  final gray = 8 + (n - 232) * 10;
  return Color.fromARGB(0xFF, gray, gray, gray);
}

/// A lightweight container for a 16-color terminal palette plus
/// the usual extra accents (background, cursor, etc.).
///
/// All colors are immutable and expressed as full 32-bit ARGB
/// values (`0xFFrrggbb`) so they can be used directly in any
/// Flutter `Color` context.
class TerminalColorTheme {
  /// 16-entry color table keyed by ANSI index (0-15).
  ///
  /// Only the indices present in the original theme are filled;
  /// lookups for missing keys will return `null`.
  final Map<int, Color> palette;

  /// Default terminal background.
  final Color background;

  /// Default terminal foreground (text) color.
  final Color foreground;

  /// Caret / cursor color.
  final Color cursorColor;

  /// Selection highlight background.
  final Color selectionBackground;

  /// Selection highlight foreground (text when selected).
  final Color selectionForeground;

  const TerminalColorTheme({
    required this.palette,
    required this.background,
    required this.foreground,
    required this.cursorColor,
    required this.selectionBackground,
    required this.selectionForeground,
  });

  /// The theme defined in your prompt, ready to drop in.
  static const TerminalColorTheme materialDark = TerminalColorTheme(
    palette: {
      0: Color(0xFF252525),
      1: Color(0xFFFF443E),
      2: Color(0xFFC3D82C),
      3: Color(0xFFFFC135),
      4: Color(0xFF42A5F5),
      5: Color(0xFFD81B60),
      6: Color(0xFF00ACC1),
      7: Color(0xFFF5F5F5),
      // Bright variants (index 8 is intentionally missing in source data)
      9: Color(0xFFFF443E),
      10: Color(0xFFC3D82C),
      11: Color(0xFFFFC135),
      12: Color(0xFF42A5F5),
      13: Color(0xFFD81B60),
      14: Color(0xFF00ACC1),
      15: Color(0xFFF5F5F5),
    },
    background: Color(0xFF151515),
    foreground: Color(0xFFA1B0B8),
    cursorColor: Color(0xFFEE6857),
    selectionBackground: Color(0xFF323232),
    selectionForeground: Color(0xFFCFCFCF),
  );
}
