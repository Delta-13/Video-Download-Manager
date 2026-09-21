import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

class Palette {
  final bool dark;
  const Palette(this.dark);
  Color get base => Color(dark ? 0xFF0B0C0A : 0xFFF3F5F1);
  Color get surface => Color(dark ? 0xFF161914 : 0xFFF3F5F1);
  Color get text => Color(dark ? 0xFFF3F5F1 : 0xFF161914);
  Color get secondary => Color(dark ? 0xFFAFB8A6 : 0xFF4C5448);
  Color get accent => Color(dark ? 0xFFFFB800 : 0xFF805800);
  Color get border => Color(dark ? 0xFF77816D : 0xFF747E6D);
  Color get onAccent => Color(dark ? 0xFF0B0C0A : 0xFFFFFFFF);
  static Palette of(BuildContext c) =>
      Palette(Theme.of(c).brightness == Brightness.dark);
}

Duration motion(BuildContext context, int ms) =>
    MediaQuery.disableAnimationsOf(context)
    ? Duration.zero
    : Duration(milliseconds: ms);

ThemeData industrialTheme(bool dark) {
  final c = Palette(dark);
  final colors = ColorScheme(
    brightness: dark ? Brightness.dark : Brightness.light,
    primary: c.accent,
    onPrimary: c.onAccent,
    secondary: c.accent,
    onSecondary: c.onAccent,
    error: c.accent,
    onError: c.onAccent,
    surface: c.surface,
    onSurface: c.text,
    outline: c.border,
    onSurfaceVariant: c.secondary,
    surfaceContainerHighest: c.surface,
  );
  final base = ThemeData(
    useMaterial3: true,
    colorScheme: colors,
    scaffoldBackgroundColor: c.base,
    fontFamily: 'JetBrains Mono',
    fontFamilyFallback: const ['Sarasa Mono SC'],
  );
  const rectangle = RoundedRectangleBorder(borderRadius: BorderRadius.zero);
  final button = ButtonStyle(
    shape: const WidgetStatePropertyAll(rectangle),
    animationDuration: const Duration(milliseconds: 150),
    minimumSize: const WidgetStatePropertyAll(Size(40, 40)),
    side: WidgetStateProperty.resolveWith(
      (states) => states.contains(WidgetState.focused)
          ? BorderSide(color: c.accent, width: 2)
          : BorderSide.none,
    ),
    mouseCursor: WidgetStateProperty.resolveWith(
      (s) => s.contains(WidgetState.disabled)
          ? SystemMouseCursors.basic
          : SystemMouseCursors.click,
    ),
  );
  return base.copyWith(
    textTheme: base.textTheme.apply(bodyColor: c.text, displayColor: c.text),
    filledButtonTheme: FilledButtonThemeData(
      style: button.copyWith(
        side: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.focused)
              ? BorderSide(color: c.onAccent, width: 2)
              : BorderSide.none,
        ),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: button.copyWith(
        side: WidgetStateProperty.resolveWith(
          (states) => BorderSide(
            color: states.contains(WidgetState.focused) ? c.accent : c.border,
            width: states.contains(WidgetState.focused) ? 2 : 1,
          ),
        ),
      ),
    ),
    textButtonTheme: TextButtonThemeData(style: button),
    iconButtonTheme: IconButtonThemeData(style: button),
    checkboxTheme: CheckboxThemeData(
      shape: rectangle,
      side: WidgetStateBorderSide.resolveWith(
        (states) => BorderSide(
          color: states.contains(WidgetState.focused) ? c.accent : c.border,
          width: states.contains(WidgetState.focused) ? 2 : 1,
        ),
      ),
      mouseCursor: WidgetStateProperty.resolveWith(
        (s) => s.contains(WidgetState.disabled)
            ? SystemMouseCursors.basic
            : SystemMouseCursors.click,
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: c.base,
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.zero,
        borderSide: BorderSide(color: c.border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.zero,
        borderSide: BorderSide(color: c.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.zero,
        borderSide: BorderSide(color: c.accent, width: 2),
      ),
      hintStyle: TextStyle(color: c.secondary, fontSize: 13),
    ),
    dialogTheme: DialogThemeData(shape: rectangle, backgroundColor: c.surface),
    tooltipTheme: TooltipThemeData(
      decoration: BoxDecoration(color: c.text),
      textStyle: TextStyle(color: c.base, fontFamily: 'Sarasa Mono SC'),
    ),
    dividerTheme: DividerThemeData(
      color: c.border.withValues(alpha: .35),
      thickness: 1,
      space: 1,
    ),
    progressIndicatorTheme: ProgressIndicatorThemeData(
      color: c.accent,
      linearTrackColor: c.border.withValues(alpha: .35),
      linearMinHeight: 3,
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: c.text,
      contentTextStyle: TextStyle(color: c.base, fontFamily: 'Sarasa Mono SC'),
    ),
  );
}

class VIcon extends StatelessWidget {
  final String name;
  final double size;
  final Color? color;
  const VIcon(this.name, {super.key, this.size = 20, this.color});
  @override
  Widget build(BuildContext context) => SvgPicture.asset(
    'assets/icons/$name.svg',
    width: size,
    height: size,
    excludeFromSemantics: true,
    colorFilter: ColorFilter.mode(
      color ?? Palette.of(context).text,
      BlendMode.srcIn,
    ),
  );
}

/// A visible keyboard outline for custom navigation and task rows.
class KeyboardFrame extends StatefulWidget {
  final Widget child;
  const KeyboardFrame({super.key, required this.child});
  @override
  State<KeyboardFrame> createState() => _KeyboardFrameState();
}

class _KeyboardFrameState extends State<KeyboardFrame> {
  bool focused = false;
  @override
  Widget build(BuildContext context) => Focus(
    canRequestFocus: false,
    skipTraversal: true,
    onFocusChange: (value) => setState(() => focused = value),
    child: DecoratedBox(
      position: DecorationPosition.foreground,
      decoration: BoxDecoration(
        border: Border.all(
          color: focused ? Palette.of(context).accent : Colors.transparent,
          width: 2,
        ),
      ),
      child: widget.child,
    ),
  );
}

class ActionIcon extends StatelessWidget {
  final String icon, label;
  final VoidCallback? onPressed;
  const ActionIcon(this.icon, this.label, this.onPressed, {super.key});
  @override
  Widget build(BuildContext context) => Semantics(
    label: label,
    button: true,
    child: Tooltip(
      message: label,
      child: IconButton(
        onPressed: onPressed,
        icon: VIcon(
          icon,
          color: onPressed == null ? Palette.of(context).secondary : null,
        ),
        tooltip: null,
      ),
    ),
  );
}

class Glass extends StatelessWidget {
  final Widget child;
  final bool reduced;
  final EdgeInsetsGeometry? padding;
  const Glass({
    super.key,
    required this.child,
    this.reduced = false,
    this.padding,
  });
  @override
  Widget build(BuildContext context) {
    final c = Palette.of(context);
    final content = Container(
      padding: padding,
      decoration: BoxDecoration(
        color: c.surface.withValues(alpha: reduced ? 1 : .94),
        border: Border.all(color: c.border.withValues(alpha: .35)),
      ),
      child: child,
    );
    if (reduced) {
      return content;
    }
    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
        child: content,
      ),
    );
  }
}

class IndustrialBackdrop extends CustomPainter {
  final Palette palette;
  IndustrialBackdrop(this.palette);
  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = palette.base);
    final rule = Paint()
      ..color = palette.border.withValues(alpha: .045)
      ..strokeWidth = 1;
    for (double x = 0; x < size.width; x += 64) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), rule);
    }
    for (double y = 0; y < size.height; y += 64) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), rule);
    }
    final plate = Paint()
      ..color = palette.border.withValues(alpha: .18)
      ..strokeWidth = 28;
    canvas.drawLine(
      Offset(-40, size.height * .72),
      Offset(200, size.height * .35),
      plate,
    );
    canvas.drawLine(
      Offset(size.width * .5, -28),
      Offset(size.width * .78, 140),
      plate,
    );
  }

  @override
  bool shouldRepaint(IndustrialBackdrop oldDelegate) =>
      palette.dark != oldDelegate.palette.dark;
}

class BusyButton extends StatelessWidget {
  final bool busy;
  final String text, busyText;
  final VoidCallback? onPressed;
  const BusyButton({
    super.key,
    required this.busy,
    required this.text,
    required this.busyText,
    this.onPressed,
  });
  @override
  Widget build(BuildContext context) => FilledButton(
    onPressed: busy ? null : onPressed,
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (busy) ...[
          const SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          const SizedBox(width: 10),
        ],
        Text(busy ? busyText : text),
      ],
    ),
  );
}

void showMessage(BuildContext context, Object message) {
  final text = message is FormatException
      ? message.message
      : message is StateError
      ? message.message
      : message.toString();
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(text.toString()),
      behavior: SnackBarBehavior.floating,
    ),
  );
}
