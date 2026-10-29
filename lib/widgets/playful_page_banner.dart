import 'package:flutter/material.dart';

import '../core/theme.dart';

/// A small, page-specific celebration panel used across Klubb screens.
/// Its clipped decorative shapes keep pages playful without distracting from content.
class PlayfulPageBanner extends StatelessWidget {
  final String eyebrow;
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final Color accent;
  final EdgeInsetsGeometry margin;

  const PlayfulPageBanner({
    super.key,
    required this.eyebrow,
    required this.title,
    required this.subtitle,
    required this.icon,
    this.color = const Color(0x246C63FF),
    this.accent = MyClubTheme.accentYellow,
    this.margin = const EdgeInsets.fromLTRB(16, 10, 16, 10),
  });

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 520),
      curve: Curves.easeOutCubic,
      builder: (context, progress, child) => Opacity(
        opacity: progress,
        child: Transform.translate(
          offset: Offset(0, 10 * (1 - progress)),
          child: child,
        ),
      ),
      child: Container(
        width: double.infinity,
        margin: margin,
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Stack(
          children: [
            Positioned(
              right: -22,
              top: -34,
              child: _Blob(size: 94, color: accent.withValues(alpha: .72)),
            ),
            Positioned(
              right: 44,
              bottom: -48,
              child: _Blob(
                size: 76,
                color: MyClubTheme.accentCoral.withValues(alpha: .55),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 17, 18, 18),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            color: MyClubTheme.canvas.withValues(alpha: .86),
                            borderRadius: BorderRadius.circular(30),
                          ),
                          child: Text(
                            eyebrow.toUpperCase(),
                            style: const TextStyle(
                              color: MyClubTheme.brand,
                              fontSize: 9,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 1.0,
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.titleLarge
                              ?.copyWith(
                                fontSize: 21,
                                height: 1.16,
                                fontWeight: FontWeight.w700,
                                letterSpacing: -.45,
                                color: MyClubTheme.ink,
                              ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          subtitle,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(
                                color: MyClubTheme.ink.withValues(alpha: .8),
                                height: 1.35,
                              ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      color: MyClubTheme.canvas.withValues(alpha: .88),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: MyClubTheme.canvas.withValues(alpha: .92),
                        width: 1.5,
                      ),
                    ),
                    child: Icon(icon, color: MyClubTheme.brand, size: 29),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Blob extends StatelessWidget {
  final double size;
  final Color color;
  const _Blob({required this.size, required this.color});

  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(color: color, shape: BoxShape.circle),
  );
}
