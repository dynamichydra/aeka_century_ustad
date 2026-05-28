import 'package:century_ai/features/home/services/home_service.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'home_state.dart';

class HomeCubit extends Cubit<HomeState> {
  final HomeService _homeService = HomeService();

  HomeCubit() : super(const HomeState());

  void fetchResults([String? query]) async {
    final effectiveQuery = query ?? state.searchQuery;
    
    // Update state so the rest of the app knows the current query
    if (query != null && query != state.searchQuery) {
      emit(state.copyWith(
        searchQuery: query, 
        isLoading: true,
        isTrendingShowing: false,
        isLikedShowing: false,
      ));
    } else {
      emit(state.copyWith(
        isLoading: true,
        isTrendingShowing: false,
        isLikedShowing: false,
      ));
    }

    // Simulate API delay
    await Future.delayed(const Duration(milliseconds: 1500));

    _homeService.filterProducts(
      query: effectiveQuery,
      isExterior: state.isExterior,
      isTrending: state.isTrendingShowing,
      isLiked: state.isLikedShowing,
      category: state.selectedIndex == 0 ? 'Interiors' : 'Furnitures',
    );

    emit(state.copyWith(isLoading: false));
  }

  void setExterior(bool value) {
    emit(state.copyWith(
      isExterior: value,
      isTrendingShowing: false,
      isLikedShowing: false,
    ));
    logState();
  }

  void toggleExterior() {
    setExterior(!state.isExterior);
  }

  void setTrending(bool value) {
    emit(state.copyWith(isTrendingShowing: value));
    logState();
  }

  void toggleTrending() {
    final newValue = !state.isTrendingShowing;
    if (newValue) {
      emit(state.copyWith(isTrendingShowing: true, isLikedShowing: false));
    } else {
      emit(state.copyWith(isTrendingShowing: false));
    }
    logState();
  }

  void toggleLiked() {
    final newValue = !state.isLikedShowing;
    if (newValue) {
      emit(state.copyWith(isLikedShowing: true, isTrendingShowing: false));
    } else {
      emit(state.copyWith(isLikedShowing: false));
    }
    logState();
  }

  void setSelectedIndex(int index) {
    emit(state.copyWith(
      selectedIndex: index,
      isTrendingShowing: false,
      isLikedShowing: false,
    ));
    logState();
  }

  void setSearchQuery(String query) {
    emit(state.copyWith(
      searchQuery: query,
      isTrendingShowing: false,
      isLikedShowing: false,
    ));
    logState();
  }

  void clearSearch() {
    emit(state.copyWith(
      searchQuery: '',
      isTrendingShowing: false,
      isLikedShowing: false,
    ));
    logState();
  }

  void resetHomeState() {
    emit(const HomeState());
    logState();
  }

  void resetFilters() {
    emit(state.copyWith(isTrendingShowing: false, isLikedShowing: false));
    logState();
  }

  void logState() {
    // debugPrint("--- HomeCubit State Update ---");
    // // ... rest of logState
    // debugPrint("Search Query: ${state.searchQuery}");
    // debugPrint("Mode: ${state.isExterior ? 'Exterior' : 'Interior'}");
    // debugPrint("Trending: ${state.isTrendingShowing}");
    // debugPrint("Liked: ${state.isLikedShowing}");
    // debugPrint("Category Tab: ${state.selectedIndex == 0 ? 'Interiors' : 'Furnitures'}");
    // debugPrint("----------------------------------");
  }
}
