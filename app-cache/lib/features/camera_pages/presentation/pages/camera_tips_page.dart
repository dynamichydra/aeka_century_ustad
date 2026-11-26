import 'package:flutter/material.dart';

import '../widgets/camera_tips_content.dart';

class CameraTipsPage extends StatelessWidget {
  const CameraTipsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: Colors.white,
      child: SafeArea(
        top: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          children: [
            Text(
              CameraTipsContent.title,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: Colors.grey[800],
                fontFamily: 'Urbanist',
              ),
            ),
            const SizedBox(height: 8),
            const Divider(height: 1, color: Color(0xFFEEEEEE)),
            const SizedBox(height: 12),
            const CameraTipsContent(),
          ],
        ),
      ),
    );
  }
}
