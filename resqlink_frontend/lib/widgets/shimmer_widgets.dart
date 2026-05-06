// widgets/shimmer_widgets.dart
// Shimmer loading placeholders — replace CircularProgressIndicator on list screens.
import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';
import '../theme/app_theme.dart';

/// A single shimmer rectangle placeholder.
/// [width] defaults to double.infinity; [height] is required.
class ShimmerBox extends StatelessWidget {
  final double? width;
  final double height;
  final double radius;
  final EdgeInsetsGeometry? margin;

  const ShimmerBox({
    super.key,
    this.width,
    required this.height,
    this.radius = 10,
    this.margin,
  });

  @override
  Widget build(BuildContext context) => Shimmer.fromColors(
        baseColor: AppColors.surface2,
        highlightColor: AppColors.surface3,
        child: Container(
          width: width ?? double.infinity,
          height: height,
          margin: margin,
          decoration: BoxDecoration(
            color: AppColors.surface2,
            borderRadius: BorderRadius.circular(radius),
          ),
        ),
      );
}

/// A shimmer placeholder that mimics a list of cards.
/// [itemCount] defaults to 4; [itemHeight] defaults to 72.
class ShimmerList extends StatelessWidget {
  final int itemCount;
  final double itemHeight;
  final EdgeInsetsGeometry padding;

  const ShimmerList({
    super.key,
    this.itemCount = 4,
    this.itemHeight = 72,
    this.padding = const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
  });

  @override
  Widget build(BuildContext context) => ListView.builder(
        padding: padding,
        physics: const NeverScrollableScrollPhysics(),
        shrinkWrap: true,
        itemCount: itemCount,
        itemBuilder: (_, i) => _ShimmerTile(height: itemHeight, index: i),
      );
}

class _ShimmerTile extends StatelessWidget {
  final double height;
  final int index;
  const _ShimmerTile({required this.height, required this.index});

  @override
  Widget build(BuildContext context) => Shimmer.fromColors(
        baseColor: AppColors.surface2,
        highlightColor: AppColors.surface3,
        child: Container(
          height: height,
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppColors.surface2,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: AppColors.surface3,
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    height: 12,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: AppColors.surface3,
                      borderRadius: BorderRadius.circular(6),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    height: 10,
                    width: 140,
                    decoration: BoxDecoration(
                      color: AppColors.surface3,
                      borderRadius: BorderRadius.circular(6),
                    ),
                  ),
                ],
              ),
            ),
          ]),
        ),
      );
}

/// Shimmer for the stats row (two cards side by side).
class ShimmerStatRow extends StatelessWidget {
  const ShimmerStatRow({super.key});

  @override
  Widget build(BuildContext context) => Shimmer.fromColors(
        baseColor: AppColors.surface2,
        highlightColor: AppColors.surface3,
        child: Row(children: [
          Expanded(
            child: Container(
              height: 72,
              decoration: BoxDecoration(
                color: AppColors.surface2,
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Container(
              height: 72,
              decoration: BoxDecoration(
                color: AppColors.surface2,
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ]),
      );
}
