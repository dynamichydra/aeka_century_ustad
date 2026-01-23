import 'package:century_ai/common/widgets/selectable_avatar/selectable_avatar.dart';
import 'package:century_ai/data/models/avatar_model.dart';
import 'package:flutter/material.dart';

class HorizontalAvatarList extends StatelessWidget {
  final List<AvatarModel> items;
  final VoidCallback onViewMore;

  const HorizontalAvatarList({
    super.key,
    required this.items,
    required this.onViewMore,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        ...items.take(4).map((item) {
          return Padding(
            padding: const EdgeInsets.only(right: 12),
            child: SelectableAvatar(
              imageUrl: item.category!,
              name: 'hello',
              onTap: ()=>{},
            ),
          );
        }),
        GestureDetector(
          onTap: onViewMore,
          child: Column(
            children: [
              CircleAvatar(
                radius: 28,
                backgroundColor: Colors.grey.shade300,
                child: const Icon(Icons.more_horiz),
              ),
              const SizedBox(height: 6),
              const Text('View more'),
            ],
          ),
        ),
      ],
    );
  }
}
