import 'package:flutter/material.dart';

class BusinessCardScreen extends StatelessWidget {
  const BusinessCardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Business card')),
      body: const Center(child: Text('Business Card Screen')),
    );
  }
}
