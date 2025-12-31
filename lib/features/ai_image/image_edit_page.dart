import 'dart:io';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'dummy_data.dart';
import 'package:century_ai/utils/api/gemini_image_service.dart';
import 'package:century_ai/utils/methods/temp_img_converter.dart';
import 'package:century_ai/utils/methods/temp_image_store.dart';

/// ------------------------------------------------------------
/// Helpers
/// ------------------------------------------------------------
Color hexToColor(String hex) {
  hex = hex.replaceAll("#", "");
  return Color(int.parse("FF$hex", radix: 16));
}

/// ------------------------------------------------------------
/// Image Edit Page
/// ------------------------------------------------------------
class ImageEditPage extends StatefulWidget {
  final int? id;

  const ImageEditPage({super.key, this.id});

  @override
  State<ImageEditPage> createState() => _ImageEditPageState();
}

class _ImageEditPageState extends State<ImageEditPage> {
  /// Images
  File? _originalImage;
  File? _editedImage;

  /// Selections
  Map<String, dynamic>? _selectedColor;
  Map<String, dynamic>? _selectedLamination;

  /// UI state
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _loadImage();
  }

  /// ------------------------------------------------------------
  /// Load image (camera/gallery → asset fallback)
  /// ------------------------------------------------------------
  Future<void> _loadImage() async {
    if (widget.id == null) return;

    /// 1️⃣ Camera / Gallery image
    final temp = TempImageStore.getImage(widget.id!);
    if (temp != null) {
      setState(() {
        _originalImage = temp;
        _editedImage = temp;
      });
      return;
    }

    /// 2️⃣ Asset furniture image
    final item = dummyFurnitureList.firstWhere(
          (e) => e["id"] == widget.id,
      orElse: () => {},
    );

    if (item.isEmpty) return;

    final file = await assetImageToTempFile(item["image"]);

    setState(() {
      _originalImage = file;
      _editedImage = file;
    });
  }

  /// ------------------------------------------------------------
  /// Prompt builder for Gemini
  /// ------------------------------------------------------------
  String _buildPrompt() {
    return """
You are a professional furniture visualization AI.

Apply the lamination texture "${_selectedLamination!["name"]}"
to the main wooden surfaces of the furniture.

Apply the color ${_selectedColor!["hex"]}
to secondary complementary areas.

Rules:
- Preserve original shape and proportions
- Do not change background
- Maintain realistic lighting and shadows
- Product-photography quality
""";
  }

  /// ------------------------------------------------------------
  /// Call Gemini Vision API
  /// ------------------------------------------------------------
  Future<void> _applyAI() async {
    if (_selectedColor == null || _selectedLamination == null) return;

    setState(() => _loading = true);

    final laminationFile =
    await assetImageToTempFile(_selectedLamination!["image"]);

    final result = await GeminiImageService.editImage(
      image: _originalImage!,
      lamination: laminationFile,
      prompt: _buildPrompt(),
    );

    setState(() {
      _editedImage = result;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_editedImage == null || _originalImage == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(title: const Text("AI Furniture Editor")),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            /// ---------------- IMAGE COMPARISON ----------------
            SizedBox(
              height: 220,
              child: (_editedImage != _originalImage)
                  ? ImageCompareSlider(
                before: _originalImage!,
                after: _editedImage!,
              )
                  : Image.file(_originalImage!, fit: BoxFit.cover),
            ),

            const SizedBox(height: 20),

            /// ---------------- COLORS ----------------
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                "Select Color",
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            const SizedBox(height: 8),

            SizedBox(
              height: 44,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: colorList.length,
                separatorBuilder: (_, __) => const SizedBox(width: 12),
                itemBuilder: (context, index) {
                  final col = colorList[index];
                  final selected = _selectedColor?["id"] == col["id"];

                  return GestureDetector(
                    onTap: () => setState(() => _selectedColor = col),
                    child: Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: hexToColor(col["hex"]),
                        border: Border.all(
                          color: selected ? Colors.black : Colors.transparent,
                          width: 2,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),

            const SizedBox(height: 20),

            /// ---------------- LAMINATIONS ----------------
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                "Select Lamination",
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            const SizedBox(height: 8),

            SizedBox(
              height: 56,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: laminationList.length,
                separatorBuilder: (_, __) => const SizedBox(width: 12),
                itemBuilder: (context, index) {
                  final lam = laminationList[index];
                  final selected =
                      _selectedLamination?["id"] == lam["id"];

                  return GestureDetector(
                    onTap: () =>
                        setState(() => _selectedLamination = lam),
                    child: Container(
                      width: 56,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color:
                          selected ? Colors.blue : Colors.transparent,
                          width: 2,
                        ),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child:
                        Image.asset(lam["image"], fit: BoxFit.cover),
                      ),
                    ),
                  );
                },
              ),
            ),

            const Spacer(),

            /// ---------------- APPLY BUTTON ----------------
            ElevatedButton(
              onPressed: (_loading ||
                  _selectedColor == null ||
                  _selectedLamination == null)
                  ? null
                  : _applyAI,
              style: ElevatedButton.styleFrom(
                minimumSize: const Size.fromHeight(48),
              ),
              child: _loading
                  ? const CircularProgressIndicator()
                  : const Text("Apply AI"),
            ),

            TextButton(
              onPressed: () => context.pop(),
              child: const Text("Back"),
            ),
          ],
        ),
      ),
    );
  }
}

/// ------------------------------------------------------------
/// Image Compare Slider (Before / After drag)
/// ------------------------------------------------------------
class ImageCompareSlider extends StatefulWidget {
  final File before;
  final File after;

  const ImageCompareSlider({
    super.key,
    required this.before,
    required this.after,
  });

  @override
  State<ImageCompareSlider> createState() => _ImageCompareSliderState();
}

class _ImageCompareSliderState extends State<ImageCompareSlider> {
  double _pos = 0.5;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) {
        final w = c.maxWidth;

        return GestureDetector(
          onHorizontalDragUpdate: (d) {
            setState(() {
              _pos += d.delta.dx / w;
              _pos = _pos.clamp(0.0, 1.0);
            });
          },
          child: Stack(
            children: [
              Image.file(widget.after,
                  width: w, fit: BoxFit.cover),
              ClipRect(
                child: Align(
                  alignment: Alignment.centerLeft,
                  widthFactor: _pos,
                  child: Image.file(widget.before,
                      width: w, fit: BoxFit.cover),
                ),
              ),
              Positioned(
                left: w * _pos - 1,
                top: 0,
                bottom: 0,
                child: Container(
                  width: 3,
                  color: Colors.white,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}



Widget colorPicker({
  required List<Map<String, dynamic>> colors,
  required Map<String, dynamic>? selected,
  required Function(Map<String, dynamic>) onSelect,
}) {
  return SizedBox(
    height: 48,
    child: ListView.separated(
      scrollDirection: Axis.horizontal,
      itemCount: colors.length,
      separatorBuilder: (_, __) => const SizedBox(width: 12),
      itemBuilder: (context, i) {
        final c = colors[i];
        final isSelected = selected?["id"] == c["id"];

        return GestureDetector(
          onTap: () => onSelect(c),
          child: Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: hexToColor(c["hex"]),
              border: Border.all(
                color: isSelected ? Colors.black : Colors.transparent,
                width: 2,
              ),
            ),
          ),
        );
      },
    ),
  );
}

