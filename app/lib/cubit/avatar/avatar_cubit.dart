import 'package:flutter_bloc/flutter_bloc.dart';
import '../../data/repositories/avatar_repository.dart';
import 'avatar_state.dart';

class AvatarCubit extends Cubit<AvatarState> {
  final AvatarRepository repository;

  AvatarCubit(this.repository) : super(const AvatarState());

  Future<void> loadAvatars() async {
    emit(state.copyWith(isLoading: true, error: null));

    try {
      final avatars = await repository.getAvatars();
      emit(state.copyWith(isLoading: false, avatars: avatars));
    } catch (e) {
      emit(state.copyWith(isLoading: false, error: e.toString()));
    }
  }

  void selectAvatar(int avatarId) {
    final updated = state.avatars.map((avatar) {
      return avatar.copyWith(isSelected: avatar.id == avatarId);
    }).toList();

    emit(state.copyWith(avatars: updated));
  }
}
