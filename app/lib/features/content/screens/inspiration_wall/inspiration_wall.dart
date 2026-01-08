import 'package:flutter/material.dart';

class InspirationWallScreen extends StatelessWidget {
  const InspirationWallScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Inspiration Wall')),
      body: const Center(child: Text('Inspiration Wall Screen')),
    );
  }
}
