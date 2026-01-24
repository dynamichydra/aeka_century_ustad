import 'package:flutter/material.dart';

class HorizontalIconGrid extends StatelessWidget {
  final int itemCount;
  final Widget Function(BuildContext context, int index) itemBuilder;

  const HorizontalIconGrid({
    super.key,
    required this.itemCount,
    required this.itemBuilder,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final itemWidth = constraints.maxWidth / itemCount;

        return Row(
          children: List.generate(
            itemCount,
            (index) =>
                SizedBox(width: itemWidth, child: itemBuilder(context, index)),
          ),
        );
      },
    );
  }
}
