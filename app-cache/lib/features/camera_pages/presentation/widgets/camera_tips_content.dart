import 'package:flutter/material.dart';

class CameraTipsContent extends StatelessWidget {
  const CameraTipsContent({super.key});

  static const title = 'Tips to capture best images';

  Widget _buildTipItem({
    required String imagePath,
    required String description,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Image.asset(
            imagePath,
            height: 115,
            width: double.infinity,
            fit: BoxFit.cover,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          description,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 9,
            fontWeight: FontWeight.w500,
            color: Colors.grey[700],
            fontFamily: 'Urbanist',
            height: 1.2,
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // DO'S Chip
        Center(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border.all(color: Colors.green, width: 1.2),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.check, color: Colors.green, size: 14),
                SizedBox(width: 6),
                Text(
                  "Do's",
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Colors.green,
                    fontFamily: 'Urbanist',
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),

        // Do's Grid: 2 columns
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: _buildTipItem(
                imagePath: 'assets/images/camera_alert/1.png',
                description:
                    "Use bright, even lighting. Leave extra space around the subject for cropping.",
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _buildTipItem(
                imagePath: 'assets/images/camera_alert/2.png',
                description:
                    "Keep the subject in focus. Keep the horizon level.",
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),

        // DON'TS Chip
        Center(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border.all(color: Colors.red, width: 1.2),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.close, color: Colors.red, size: 14),
                SizedBox(width: 6),
                Text(
                  "Don'ts",
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Colors.red,
                    fontFamily: 'Urbanist',
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),

        // Don'ts Grid: 2x2
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: _buildTipItem(
                imagePath: 'assets/images/camera_alert/3.png',
                description: "Don't cut off important parts of the subject.",
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _buildTipItem(
                imagePath: 'assets/images/camera_alert/4.png',
                description:
                    "No blurry or out-of-focus photos. Don't block the subject.",
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: _buildTipItem(
                imagePath: 'assets/images/camera_alert/5.png',
                description: "Avoid cluttered backgrounds.",
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _buildTipItem(
                imagePath: 'assets/images/camera_alert/6.png',
                description:
                    "Don't use a background with similar colors, use contrast for depth.",
              ),
            ),
          ],
        ),
      ],
    );
  }
}
