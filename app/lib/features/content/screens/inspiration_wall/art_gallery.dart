import 'package:century_ai/common/widgets/avatar_grid/avatar_grid.dart';
import 'package:century_ai/common/widgets/horizontal_avatar_list/horizontal_avatar_list.dart';
import 'package:century_ai/common/widgets/section_header/section_header.dart';
import 'package:century_ai/cubit/avatar/avatar_cubit.dart';
import 'package:century_ai/cubit/avatar/avatar_state.dart';
import 'package:century_ai/data/repositories/avatar_repository.dart';
import 'package:century_ai/data/services/api_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';


class ArtGallery extends StatelessWidget {
  const ArtGallery({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => AvatarCubit(AvatarRepository(ApiService()))..loadAvatars(),
      child: Scaffold(
        appBar: AppBar(title: const Text('People')),
        body: BlocBuilder<AvatarCubit, AvatarState>(
          builder: (context, state) {
            if (state.isLoading) {
              return const Center(child: CircularProgressIndicator());
            }

            if (state.error != null) {
              return Center(child: Text(state.error!));
            }

             return SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SectionHeader(title: 'Team Members', onViewAll: () {}),
                  const SizedBox(height: 16),
                  AvatarGrid(
                    avatars: state.avatars,
                    columns: 4,
                    onAvatarTap: (id) {
                      context.read<AvatarCubit>().selectAvatar(id);
                    },
                  ),
                  const SizedBox(height: 24), // spacing between sections
                  HorizontalAvatarList(
                    items: state.avatars!,
                    onViewMore: () {},
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}
