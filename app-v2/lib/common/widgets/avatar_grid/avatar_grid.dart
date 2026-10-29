import 'package:century_ai/common/widgets/selectable_avatar/selectable_avatar.dart';
import 'package:century_ai/data/models/avatar_model.dart';
import 'package:flutter/material.dart';

class AvatarGrid extends StatelessWidget {
  final List<AvatarModel> avatars;
  final int columns;
  final void Function(int) onAvatarTap;

  const AvatarGrid({
    super.key,
    required this.avatars,
    required this.columns,
    required this.onAvatarTap,
  });

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: avatars.length,
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: columns,
        mainAxisSpacing: 16,
        crossAxisSpacing: 16,
        childAspectRatio: 0.75,
      ),
      itemBuilder: (_, index) {
        final avatar = avatars[index];
        return SelectableAvatar(
          imageUrl: avatar.category!,
          name: avatar.title!,
          isSelected: avatar.isSelected,
          onTap: () => onAvatarTap(avatar.id!),
        );
      },
    );
  }
}
