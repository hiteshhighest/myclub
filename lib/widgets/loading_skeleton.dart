import 'package:flutter/material.dart';

import '../core/theme.dart';

class LoadingSkeletonList extends StatefulWidget {
  final int itemCount;
  final EdgeInsetsGeometry padding;
  final bool shrinkWrap;

  const LoadingSkeletonList({
    super.key,
    this.itemCount = 3,
    this.padding = const EdgeInsets.all(20),
    this.shrinkWrap = false,
  });

  @override
  State<LoadingSkeletonList> createState() => _LoadingSkeletonListState();
}

class _LoadingSkeletonListState extends State<LoadingSkeletonList>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final opacity = 0.055 + (_controller.value * 0.035);
        return ListView.separated(
          physics: widget.shrinkWrap
              ? const NeverScrollableScrollPhysics()
              : const AlwaysScrollableScrollPhysics(),
          shrinkWrap: widget.shrinkWrap,
          padding: widget.padding,
          itemCount: widget.itemCount,
          separatorBuilder: (_, _) => const SizedBox(height: 12),
          itemBuilder: (context, index) => _SkeletonCard(opacity: opacity),
        );
      },
    );
  }
}

class _SkeletonCard extends StatelessWidget {
  final double opacity;

  const _SkeletonCard({required this.opacity});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 96,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: MyClubTheme.brand.withValues(alpha: opacity),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: MyClubTheme.brand.withValues(alpha: opacity + 0.035),
              borderRadius: BorderRadius.circular(16),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: double.infinity,
                  height: 13,
                  decoration: BoxDecoration(
                    color: MyClubTheme.brand.withValues(alpha: opacity + 0.035),
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                const SizedBox(height: 10),
                FractionallySizedBox(
                  widthFactor: .62,
                  child: Container(
                    height: 10,
                    decoration: BoxDecoration(
                      color: MyClubTheme.brand.withValues(
                        alpha: opacity + 0.035,
                      ),
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
