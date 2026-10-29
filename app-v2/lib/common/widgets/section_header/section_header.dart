import 'package:flutter/material.dart';

class SectionHeader extends StatelessWidget {
  final String title;
  final VoidCallback? onViewAll;
  final Widget? leading;

  const SectionHeader({
    super.key,
    required this.title,
    this.onViewAll,
    this.leading,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        if (leading != null) ...[leading!, const SizedBox(width: 8)],
        Text(title, style: Theme.of(context).textTheme.titleMedium),
        const Spacer(),
        TextButton(onPressed: onViewAll, child: const Text('View all')),
      ],
    );
  }
}
