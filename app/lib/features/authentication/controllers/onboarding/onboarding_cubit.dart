import 'package:flutter_bloc/flutter_bloc.dart';

class OnboardingState {
  final int pageIndex;
  final bool isOtpStage;

  OnboardingState({required this.pageIndex, this.isOtpStage = false});

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is OnboardingState &&
          runtimeType == other.runtimeType &&
          pageIndex == other.pageIndex &&
          isOtpStage == other.isOtpStage;

  @override
  int get hashCode => pageIndex.hashCode ^ isOtpStage.hashCode;
}

class OnboardingCubit extends Cubit<OnboardingState> {
  OnboardingCubit() : super(OnboardingState(pageIndex: 0));

  void updatePageIndicator(int index) =>
      emit(OnboardingState(pageIndex: index, isOtpStage: false));

  void dotNavigationClick(int index) {
    emit(OnboardingState(pageIndex: index, isOtpStage: false));
  }

  void setOtpStage(bool value) {
    emit(OnboardingState(pageIndex: state.pageIndex, isOtpStage: value));
  }

  void nextPage() {
    if (state.pageIndex < 2) {
      emit(OnboardingState(pageIndex: state.pageIndex + 1, isOtpStage: false));
    }
  }

  void skipPage() {
    emit(OnboardingState(pageIndex: 2, isOtpStage: false));
  }
}


