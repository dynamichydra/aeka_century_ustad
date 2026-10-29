import 'package:flutter/material.dart';

class ZoomControls extends StatelessWidget {
  final VoidCallback onZoomIn;
  final VoidCallback onZoomOut;

  const ZoomControls({
    super.key,
    required this.onZoomIn,
    required this.onZoomOut,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _buildZoomButton(icon: Icons.zoom_out, onTap: onZoomOut),
        const SizedBox(width: 8),
        _buildZoomButton(icon: Icons.zoom_in, onTap: onZoomIn),
      ],
    );
  }

  Widget _buildZoomButton({
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.45),
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.15),
              blurRadius: 4,
              spreadRadius: 0,
            ),
          ],
        ),
        child: Icon(
          icon,
          color: Colors.white,
          size: 24,
        ),
      ),
    );
  }
}
