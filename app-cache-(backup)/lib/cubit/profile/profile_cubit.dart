import 'package:century_ai/cubit/profile/profile_state.dart';
import 'package:century_ai/data/models/user_profile_model.dart';
import 'package:century_ai/data/repositories/user_profile_repository.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class ProfileCubit extends Cubit<ProfileState> {
  final UserProfileRepository _userProfileRepository;

  ProfileCubit(this._userProfileRepository) : super(const ProfileState());

  Future<void> loadProfile({int userId = 1}) async {
    emit(state.copyWith(isLoading: true, errorMessage: null, isSaved: false));
    try {
      final profile = await _userProfileRepository.getProfile(userId: userId);
      emit(state.copyWith(isLoading: false, profile: profile));
    } catch (e) {
      emit(state.copyWith(isLoading: false, errorMessage: e.toString()));
    }
  }

  Future<void> updateProfile(UserProfileModel input) async {
    emit(state.copyWith(isSaving: true, errorMessage: null, isSaved: false));
    try {
      final profile = await _userProfileRepository.updateProfile(input);
      emit(state.copyWith(isSaving: false, profile: profile, isSaved: true));
    } catch (e) {
      emit(state.copyWith(isSaving: false, errorMessage: e.toString()));
    }
  }

  void clearSavedFlag() {
    emit(state.copyWith(isSaved: false));
  }
}
