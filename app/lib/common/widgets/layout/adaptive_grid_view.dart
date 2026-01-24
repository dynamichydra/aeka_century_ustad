import 'package:flutter/material.dart';
import '../../../utils/constants/sizes.dart';

class AdaptiveGridView extends StatelessWidget {
  final int crossAxisCount;
  final int itemCount;
  final Widget Function(BuildContext context, int index) itemBuilder;

  const AdaptiveGridView({
    super.key,
    required this.crossAxisCount,
    required this.itemCount,
    required this.itemBuilder,
  });

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        crossAxisSpacing: TSizes.spaceBtwItems,
        mainAxisSpacing: TSizes.spaceBtwItems,
        childAspectRatio: 1,
      ),
      itemCount: itemCount,
      itemBuilder: itemBuilder,
    );
  }
}
