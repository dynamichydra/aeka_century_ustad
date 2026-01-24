import 'package:flutter/material.dart';
import 'package:century_ai/utils/constants/sizes.dart';

class SectionList<T> extends StatelessWidget {
  final List<T> items;
  final Widget Function(BuildContext context, T item) itemBuilder;
  final Widget Function(BuildContext context, T item) headerBuilder;

  const SectionList({
    super.key,
    required this.items,
    required this.itemBuilder,
    required this.headerBuilder,
  });

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: items.length,
      separatorBuilder: (_, __) =>
          const SizedBox(height: TSizes.spaceBtwSections),
      itemBuilder: (context, index) {
        final item = items[index];
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            headerBuilder(context, item),
            const SizedBox(height: TSizes.spaceBtwItems),
            itemBuilder(context, item),
          ],
        );
      },
    );
  }
}
