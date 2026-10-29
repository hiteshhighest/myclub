import 'package:flutter/material.dart';

/// Shared card for announcements and events: leading visual, club name,
/// title, optional body, small tags, and a footer line.
class ClubInfoCard extends StatelessWidget {
  final Widget leading;
  final String title;
  final String clubName;
  final String? body;
  final List<Widget> tags;
  final IconData footerIcon;
  final String footer;
  final VoidCallback? onTap;

  const ClubInfoCard({
    super.key,
    required this.leading,
    required this.title,
    required this.clubName,
    this.body,
    this.tags = const [],
    required this.footerIcon,
    required this.footer,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    final t = Theme.of(context).textTheme;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 420),
      curve: Curves.easeOutCubic,
      builder: (context, progress, child) => Opacity(
        opacity: progress,
        child: Transform.translate(
          offset: Offset(0, 8 * (1 - progress)),
          child: child,
        ),
      ),
      child: Card(
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                leading,
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        clubName.toUpperCase(),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.8,
                          color: c.primary,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        title,
                        style: t.titleMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                          fontSize: 16,
                        ),
                      ),
                      if (body != null && body!.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Text(
                          body!,
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                          style: t.bodyMedium,
                        ),
                      ],
                      if (tags.isNotEmpty) ...[
                        const SizedBox(height: 10),
                        Wrap(spacing: 6, runSpacing: 6, children: tags),
                      ],
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Icon(footerIcon, size: 14, color: c.onSurfaceVariant),
                          const SizedBox(width: 5),
                          Expanded(
                            child: Text(
                              footer,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: t.bodySmall,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Compact replacement for Chip.
class MiniTag extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color? color;
  const MiniTag({
    super.key,
    required this.icon,
    required this.label,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final c = color ?? Theme.of(context).colorScheme.primary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: c.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: c),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: c,
            ),
          ),
        ],
      ),
    );
  }
}

/// Calendar-style leading badge for events.
class DateBadge extends StatelessWidget {
  final DateTime? date;
  const DateBadge({super.key, this.date});

  static const _months = [
    'JAN',
    'FEB',
    'MAR',
    'APR',
    'MAY',
    'JUN',
    'JUL',
    'AUG',
    'SEP',
    'OCT',
    'NOV',
    'DEC',
  ];

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    return Container(
      width: 52,
      padding: const EdgeInsets.symmetric(vertical: 7),
      decoration: BoxDecoration(
        color: c.primaryContainer,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        children: [
          Text(
            date == null ? '--' : _months[date!.month - 1],
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.8,
              color: c.primary,
            ),
          ),
          Text(
            date == null ? '?' : '${date!.day}',
            style: TextStyle(
              fontSize: 21,
              height: 1.1,
              fontWeight: FontWeight.w800,
              color: c.onPrimaryContainer,
            ),
          ),
        ],
      ),
    );
  }
}

/// Rounded icon tile for non-dated items (announcements, etc).
class IconTile extends StatelessWidget {
  final IconData icon;
  final Color? color;
  const IconTile({super.key, required this.icon, this.color});

  @override
  Widget build(BuildContext context) {
    final base = color ?? Theme.of(context).colorScheme.primary;
    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        color: base.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Icon(icon, color: base, size: 24),
    );
  }
}
