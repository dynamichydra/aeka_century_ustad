import 'package:flutter/material.dart';
import 'package:get_storage/get_storage.dart';
import 'package:century_ai/core/constants/colors.dart';

class CameraTipsBottomSheet extends StatefulWidget {
  const CameraTipsBottomSheet({super.key});

  static Future<void> show(BuildContext context) async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return const FractionallySizedBox(
          heightFactor: 0.95,
          child: CameraTipsBottomSheet(),
        );
      },
    );
  }

  @override
  State<CameraTipsBottomSheet> createState() => _CameraTipsBottomSheetState();
}

class _CameraTipsBottomSheetState extends State<CameraTipsBottomSheet> {
  bool _dontShowAgain = false;

  Widget _buildTipItem({required String imagePath, required String description}) {
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
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          children: [
            // Header Row: Title & Close Button
            Padding(
              padding: const EdgeInsets.only(left: 20.0, right: 20.0, top: 16.0, bottom: 8.0),
              child: Row(
                children: [
                  const SizedBox(width: 24), // spacer to align with close button
                  Expanded(
                    child: Text(
                      "Tips to capture best images",
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey[800],
                        fontFamily: 'Urbanist',
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close, color: Colors.grey, size: 24),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
            ),
            const Divider(height: 1, color: Color(0xFFEEEEEE)),
            
            // Statically sized Content (No Scroll)
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 12.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
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
                            description: "Use bright, even lighting. Leave extra space around the subject for cropping.",
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: _buildTipItem(
                            imagePath: 'assets/images/camera_alert/2.png',
                            description: "Keep the subject in focus. Keep the horizon level.",
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
                            description: "No blurry or out-of-focus photos. Don't block the subject.",
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
                            description: "Don't use a background with similar colors, use contrast for depth.",
                          ),
                        ),
                      ],
                    ),
                    
                    const Spacer(),
                    
                    // Don't Show Again checkbox
                    InkWell(
                      onTap: () {
                        setState(() {
                          _dontShowAgain = !_dontShowAgain;
                        });
                      },
                      splashColor: Colors.transparent,
                      highlightColor: Colors.transparent,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            width: 16,
                            height: 16,
                            decoration: BoxDecoration(
                              border: Border.all(
                                color: Colors.grey[400]!,
                                width: 1.5,
                              ),
                              borderRadius: BorderRadius.circular(3),
                              color: _dontShowAgain ? Colors.grey[600] : Colors.transparent,
                            ),
                            child: _dontShowAgain
                                ? const Icon(
                                    Icons.check,
                                    size: 12,
                                    color: Colors.white,
                                  )
                                : null,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            "Don't Show Again",
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                              color: Colors.grey[600],
                              fontFamily: 'Urbanist',
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    
                    // Got it button
                    Center(
                      child: SizedBox(
                        width: 160,
                        child: OutlinedButton(
                          onPressed: () {
                            if (_dontShowAgain) {
                              final box = GetStorage();
                              box.write('dont_show_camera_tips', true);
                            }
                            Navigator.pop(context);
                          },
                          style: OutlinedButton.styleFrom(
                            side: BorderSide(color: Colors.grey[300]!, width: 1),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(24),
                            ),
                          ),
                          child: Text(
                            "Got it",
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: Colors.grey[800],
                              fontFamily: 'Urbanist',
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
