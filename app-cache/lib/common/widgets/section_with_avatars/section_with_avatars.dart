import 'package:flutter/material.dart';
import 'package:century_ai/common/widgets/avatar_grid/avatar_grid.dart';
import 'package:century_ai/common/widgets/section_header/section_header.dart';
import 'package:century_ai/data/models/avatar_model.dart';

class SectionWithAvatars extends StatelessWidget {
  final String title;
  final List<AvatarModel> avatars;
  final int columns;
  final VoidCallback onViewAll;
  final void Function(int avatarId) onAvatarTap;

  const SectionWithAvatars({
    super.key,
    required this.title,
    required this.avatars,
    required this.columns,
    required this.onViewAll,
    required this.onAvatarTap,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader(title: title, onViewAll: onViewAll),
        const SizedBox(height: 12),
        AvatarGrid(
          avatars: avatars,
          columns: columns,
          onAvatarTap: onAvatarTap,
        ),
      ],
    );
  }
}
