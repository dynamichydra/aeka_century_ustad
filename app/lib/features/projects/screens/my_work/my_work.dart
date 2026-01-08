import 'package:flutter/material.dart';

class MyWorkScreen extends StatelessWidget {
  const MyWorkScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('My Work')),
      body: const Center(child: Text('My Work Screen')),
    );
  }
}
