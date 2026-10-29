import 'package:flutter/material.dart';

import '../../core/theme.dart';

/// The shared Klubb mark used on authentication screens.
/// A gentle entrance animation gives the app a little motion without an extra dependency.
class BrandMark extends StatefulWidget {
  const BrandMark({super.key, this.size = 78});
  final double size;

  @override
  State<BrandMark> createState() => _BrandMarkState();
}

class _BrandMarkState extends State<BrandMark>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 650),
  )..forward();
  late final Animation<double> _scale = CurvedAnimation(
    parent: _controller,
    curve: Curves.easeOutBack,
  );
  late final Animation<double> _fade = CurvedAnimation(
    parent: _controller,
    curve: Curves.easeOut,
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => FadeTransition(
    opacity: _fade,
    child: ScaleTransition(
      scale: _scale,
      child: Container(
        width: widget.size,
        height: widget.size,
        padding: const EdgeInsets.all(5),
        decoration: BoxDecoration(
          color: MyClubTheme.canvas,
          borderRadius: BorderRadius.circular(widget.size * .27),
          boxShadow: [
            BoxShadow(
              color: MyClubTheme.brand.withValues(alpha: .16),
              blurRadius: 22,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(widget.size * .22),
          child: Image.asset(
            'assets/branding/myclub_logo.png',
            fit: BoxFit.contain,
            errorBuilder: (context, error, stackTrace) => Icon(
              Icons.groups_rounded,
              color: MyClubTheme.brand,
              size: widget.size * .52,
            ),
          ),
        ),
      ),
    ),
  );
}
