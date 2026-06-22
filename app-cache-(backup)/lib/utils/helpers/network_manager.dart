import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Manages the network connectivity status and provides methods to check and handle connectivity changes.
class NetworkCubit extends Cubit<List<ConnectivityResult>> {
  NetworkCubit() : super([]) {
    _connectivitySubscription = _connectivity.onConnectivityChanged.listen(_updateConnectionStatus);
  }

  final Connectivity _connectivity = Connectivity();
  late StreamSubscription<List<ConnectivityResult>> _connectivitySubscription;

  /// Update the connection status based on changes in connectivity and show a relevant popup for no internet connection.
  void _updateConnectionStatus(List<ConnectivityResult> result) {
    emit(result);
    // Note: The UI (main.dart) listens to this Cubit and shows a toast when connection is lost.
  }

  /// Check the internet connection status.
  /// Returns `true` if connected, `false` otherwise.
  Future<bool> isConnected() async {
    try {
      final result = await _connectivity.checkConnectivity();
      if (result.any((element) => element == ConnectivityResult.none)) {
        return false;
      } else {
        return true;
      }
    } on PlatformException catch (_) {
      return false;
    }
  }

  @override
  Future<void> close() {
    _connectivitySubscription.cancel();
    return super.close();
  }
}
