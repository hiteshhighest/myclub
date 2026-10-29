import 'package:flutter/material.dart';

import '../core/theme.dart';

/// Soft, playful backdrop for authentication screens.
/// Decorations are deliberately behind the content and never intercept taps.
class PlayfulAuthBackground extends StatelessWidget {
  final Widget child;
  const PlayfulAuthBackground({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        const DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [MyClubTheme.canvas, Color(0x146C63FF)],
            ),
          ),
        ),
        const Positioned(
          top: -78,
          right: -52,
          child: _Blob(size: 210, color: Color(0x226C63FF)),
        ),
        const Positioned(
          bottom: -82,
          left: -64,
          child: _Blob(size: 220, color: Color(0x33A7D7C5)),
        ),
        const Positioned(
          bottom: 110,
          right: -58,
          child: _Blob(size: 132, color: Color(0x22FF8F7A)),
        ),
        child,
      ],
    );
  }
}

class _Blob extends StatelessWidget {
  final double size;
  final Color color;
  const _Blob({required this.size, required this.color});

  @override
  Widget build(BuildContext context) => IgnorePointer(
    child: Container(
      width: size,
      height: size,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    ),
  );
}
