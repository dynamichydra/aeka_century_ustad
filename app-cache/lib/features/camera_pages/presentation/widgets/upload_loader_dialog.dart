
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:century_ai/core/constants/colors.dart';

class UploadLoaderDialog extends StatefulWidget {
  const UploadLoaderDialog({super.key});

  @override
  State<UploadLoaderDialog> createState() => _UploadLoaderDialogState();
}

class _UploadLoaderDialogState extends State<UploadLoaderDialog> {
  static const List<String> _messages = [
    "Uploading image...",
    "Analyzing image...",
    "Detecting furniture...",
    "Almost done...", // The timer will stop here
  ];

  int _currentIndex = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 10), (timer) {
      if (!mounted) return;

      // Check if we are at the last message ("Almost done...")
      if (_currentIndex >= _messages.length - 1) {
        _timer?.cancel(); // Stops the timer completely
        return;
      }

      setState(() {
        _currentIndex++; // Just increment instead of using the modulo (%) operator
      });
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: Material(
        type: MaterialType.transparency,
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(
                width: 42,
                height: 42,
                child: CircularProgressIndicator(
                  color: TColors.primary,
                  strokeWidth: 3,
                ),
              ),
              const SizedBox(height: 20),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 400),
                layoutBuilder: (currentChild, previousChildren) {
                  return Stack(
                    alignment: Alignment.center,
                    children: [
                      ...previousChildren,
                      if (currentChild != null) currentChild,
                    ],
                  );
                },
                transitionBuilder: (child, animation) => FadeTransition(
                  opacity: animation,
                  child: ScaleTransition(
                    scale: Tween<double>(
                      begin: 0.95,
                      end: 1.0,
                    ).animate(animation),
                    child: child,
                  ),
                ),
                child: Text(
                  _messages[_currentIndex],
                  key: ValueKey<int>(_currentIndex),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                    letterSpacing: 0.3,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
