import 'package:century_ai/features/home/services/home_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'home_state.dart';

class HomeCubit extends Cubit<HomeState> {
  final HomeService _homeService = HomeService();

  HomeCubit() : super(const HomeState());

  void fetchResults([String? query]) {
    final effectiveQuery = query ?? state.searchQuery;
    
    // Update state so the rest of the app knows the current query
    if (query != null && query != state.searchQuery) {
      emit(state.copyWith(searchQuery: query));
    }

    _homeService.filterProducts(
      query: effectiveQuery,
      isExterior: state.isExterior,
      isTrending: state.isTrendingShowing,
      isLiked: state.isLikedShowing,
      category: state.selectedIndex == 0 ? 'Interiors' : 'Furnitures',
    );
  }

  void setExterior(bool value) {
    emit(state.copyWith(isExterior: value));
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
    setTrending(!state.isTrendingShowing);
  }

  void setLiked(bool value) {
    emit(state.copyWith(isLikedShowing: value));
    logState();
  }

  void toggleLiked() {
    setLiked(!state.isLikedShowing);
  }

  void setSelectedIndex(int index) {
    emit(state.copyWith(selectedIndex: index));
    logState();
  }

  void setSearchQuery(String query) {
    emit(state.copyWith(searchQuery: query));
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
