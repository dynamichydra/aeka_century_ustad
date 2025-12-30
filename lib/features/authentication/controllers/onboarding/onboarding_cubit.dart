import 'package:flutter_bloc/flutter_bloc.dart';

class OnboardingCubit extends Cubit<int> {
  OnboardingCubit() : super(0);

  void updatePageIndicator(int index) => emit(index);

  void dotNavigationClick(int index) {
    emit(index);
    // Note: The UI layer will need to listen to this state change to animate the PageController
  }

  void nextPage() {
    if (state < 2) {
      emit(state + 1);
    }
  }

  void skipPage() {
    emit(2); // Jump to the last page (index 2)
  }
}
