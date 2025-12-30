import 'package:flutter/material.dart';

class QuotationScreen extends StatelessWidget {
  const QuotationScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Quotation')),
      body: const Center(child: Text('Quotation Screen')),
    );
  }
}
