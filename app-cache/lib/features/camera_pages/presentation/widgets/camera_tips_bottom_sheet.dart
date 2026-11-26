import 'package:flutter/material.dart';
import 'package:get_storage/get_storage.dart';
import 'camera_tips_content.dart';

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
              padding: const EdgeInsets.only(
                left: 20.0,
                right: 20.0,
                top: 16.0,
                bottom: 8.0,
              ),
              child: Row(
                children: [
                  const SizedBox(
                    width: 24,
                  ), // spacer to align with close button
                  Expanded(
                    child: Text(
                      CameraTipsContent.title,
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

            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20.0,
                  vertical: 12.0,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Expanded(
                      child: SingleChildScrollView(child: CameraTipsContent()),
                    ),
                    const SizedBox(height: 16),

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
                              color: _dontShowAgain
                                  ? Colors.grey[600]
                                  : Colors.transparent,
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
                            side: BorderSide(
                              color: Colors.grey[300]!,
                              width: 1,
                            ),
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
