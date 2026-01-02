import 'dart:io';
import 'dart:typed_data';
// import 'package:century_ai/features/ai_image/image_edit_page.dart';

import 'package:century_ai/common/widgets/inputs/text_field.dart';
import 'package:century_ai/features/camera_pages/widgets/ImageCompareSlider.dart';
import 'package:century_ai/features/home/screens/widgets/home_drawer.dart';
import 'package:flutter/material.dart';
import 'package:iconsax/iconsax.dart';
import 'package:century_ai/utils/constants/image_strings.dart';
import 'package:toggle_switch/toggle_switch.dart';
import 'dummy_data.dart';
import 'package:century_ai/utils/api/gemini_image_service.dart';
import 'package:century_ai/utils/methods/temp_img_converter.dart';
import 'package:century_ai/utils/constants/sizes.dart';
import 'dart:ui' as ui;
import 'package:flutter/rendering.dart';

Color hexToColor(String hex) {
  hex = hex.replaceAll("#", "");
  return Color(int.parse("FF$hex", radix: 16));
}

class ImageEditPage extends StatefulWidget {
  final File imageFile;

  const ImageEditPage({super.key, required this.imageFile});

  @override
  State<ImageEditPage> createState() => _ImageEditPageState();
}

class _ImageEditPageState extends State<ImageEditPage> {
  final GlobalKey _screenKey = GlobalKey();
  bool _pickingColor = false;
  ui.Image? _screenImage;
  ByteData? _pixelData;
  Offset _touchPos = Offset.zero;
  Color _pickedColor = Colors.transparent;

  bool _isInterior = true;

  Color _getPixelColor(ByteData data, ui.Image img, Offset pos) {
    final x = pos.dx.round().clamp(0, img.width - 1);
    final y = pos.dy.round().clamp(0, img.height - 1);

    final offset = (y * img.width + x) * 4;

    return Color.fromARGB(
      data.getUint8(offset + 3),
      data.getUint8(offset),
      data.getUint8(offset + 1),
      data.getUint8(offset + 2),
    );
  }

  File? _originalImage;
  File? _editedImage;

  Map<String, dynamic>? _selectedColor;
  Map<String, dynamic>? _selectedLamination;

  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _originalImage = widget.imageFile;
    _editedImage = widget.imageFile;
  }

  String _buildPrompt() {
    return """
You are a professional furniture visualization AI.

Apply the lamination texture "${_selectedLamination!["name"]}"
to the main wooden surfaces of the furniture.

Apply the color ${_selectedColor!["hex"]}
to secondary complementary areas.

Rules:
- Preserve original shape
- Do not change background
- Maintain realistic lighting
""";
  }

  Future<void> _applyAI() async {
    if (_selectedColor == null || _selectedLamination == null) return;

    setState(() => _loading = true);

    final laminationFile = await assetImageToTempFile(
      _selectedLamination!["image"],
    );

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

  Future<ui.Image> _captureScreen() async {
    final boundary =
        _screenKey.currentContext!.findRenderObject() as RenderRepaintBoundary;

    return await boundary.toImage(pixelRatio: 3.0);
  }

  Future<ByteData> _toPixels(ui.Image image) async {
    return (await image.toByteData(format: ui.ImageByteFormat.rawRgba))!;
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      key: _screenKey,
      child: Scaffold(
        appBar: AppBar(
          leading: Builder(
            builder: (context) => IconButton(
              icon: const Icon(Iconsax.menu_1, color: Colors.black),
              onPressed: () => Scaffold.of(context).openDrawer(),
            ),
          ),
          actions: const [
            Padding(
              padding: EdgeInsets.only(right: TSizes.defaultSpace),
              child: Image(
                image: AssetImage(TImages.smallLogo),
                width: 30,
                height: 30,
              ),
            ),
          ],
          backgroundColor: Colors.white,
          elevation: 0,
        ),
        drawer: const HomeDrawer(),
        backgroundColor: Colors.white,
        body: GestureDetector(
          onPanDown: (d) async {
            if (!_pickingColor) return;

            _screenImage ??= await _captureScreen();
            _pixelData ??= await _toPixels(_screenImage!);

            setState(() {
              _touchPos = d.localPosition;
              _pickedColor = _getPixelColor(
                _pixelData!,
                _screenImage!,
                _touchPos,
              );
            });
          },
          onPanUpdate: (d) {
            if (!_pickingColor) return;

            setState(() {
              _touchPos = d.localPosition;
              _pickedColor = _getPixelColor(
                _pixelData!,
                _screenImage!,
                _touchPos,
              );
            });
          },
          onPanEnd: (_) {
            if (!_pickingColor) return;

            // Save picked color
            setState(() {
              _selectedColor = {
                "id": "picked",
                "hex":
                    "#${_pickedColor.value.toRadixString(16).substring(2).toUpperCase()}",
              };
              _pickingColor = false;
            });
          },
          child: Stack(
            children: [
              /// ---------------- IMAGE AREA ----------------
              Positioned.fill(
                child: SafeArea(
                  bottom: false,
                  child: (_editedImage != _originalImage)
                      ? ImageCompareSlider(
                          before: _originalImage!,
                          after: _editedImage!,
                        )
                      : Image.file(_originalImage!, fit: BoxFit.cover),
                ),
              ),

              /// ---------------- BOTTOM PANEL ----------------
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: Container(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(20),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.12),
                        blurRadius: 12,
                        offset: const Offset(0, -4),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(height: 20),
                      const Text(
                        "Design",
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 24,
                        ),
                      ),

                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text("AI Based Color & Pattern Search"),
                          interiorExteriorToggle(),
                        ],
                      ),
                      SizedBox(height: 5),
                      const TTextField(
                        labelText: 'Search...',
                        prefixIcon: Icon(Iconsax.search_normal),
                        fillColor: Colors.white,
                      ),
                      SizedBox(height: 5),

                      /// -------- COLORS --------
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            "Select Color",
                            style: TextStyle(fontWeight: FontWeight.w600),
                          ),
                          IconButton(
                            icon: Icon(
                              Icons.colorize,
                              color: _pickingColor ? Colors.blue : Colors.black,
                            ),
                            tooltip: "Pick color from screen",
                            onPressed: () {
                              setState(() {
                                _pickingColor = true;
                                _screenImage = null; // force fresh capture
                                _pixelData = null;
                              });
                            },
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      _colorPicker(),

                      const SizedBox(height: 16),

                      /// -------- LAMINATIONS --------
                      const Text(
                        "Pattern & Texture",
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 8),
                      _laminationPicker(),

                      const SizedBox(height: 20),

                      /// -------- APPLY BUTTON --------
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          SizedBox(width: 5,),
                          InkWell(
                            onTap: () {},
                            child: Container(
                              width: 50,
                              height: 50,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: const Color(0xFFE5E5E5),
                                  width: 0,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    blurRadius: 3,
                                    color: Color(0xFF646464),
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                                color: Colors.white,
                              ),
                              child: const Center(
                                child: Icon(Icons.bookmark, size: 24),
                              ),
                            ),
                          ),
                          SizedBox(
                            width: 120,
                            height: 58,
                            child: ElevatedButton(
                              onPressed:
                                  (_loading ||
                                      _selectedColor == null ||
                                      _selectedLamination == null)
                                  ? null
                                  : _applyAI,
                              child: _loading
                                  ? const CircularProgressIndicator()
                                  : const Text("Apply"),
                            ),
                          ),
                          InkWell(
                            onTap: () {},
                            child: Container(
                              width: 50,
                              height: 50,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: const Color(0xFFE5E5E5),
                                  width: 0,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    blurRadius: 3,
                                    color: Color(0xFF646464),
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                                color: Colors.white,
                              ),
                              child: const Center(
                                child: Icon(Icons.share, size: 24),
                              ),
                            ),
                          ),
                          SizedBox(width: 5,),
                        ],
                      ),
                      const SizedBox(height: 30),
                    ],
                  ),
                ),
              ),

              if (_pickingColor)
                Positioned(
                  left: _touchPos.dx - 18,
                  top: _touchPos.dy - 48,
                  child: Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: _pickedColor,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2),
                      boxShadow: const [
                        BoxShadow(color: Colors.black26, blurRadius: 6),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  /// ---------------- COLOR PICKER ----------------
  Widget _colorPicker() {
    return SizedBox(
      height: 44,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: colorList.length,
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemBuilder: (context, i) {
          final c = colorList[i];
          final selected = _selectedColor?["id"] == c["id"];

          return GestureDetector(
            onTap: () => setState(() => _selectedColor = c),
            child: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: hexToColor(c["hex"]),
                border: Border.all(
                  color: selected ? Colors.black : Colors.transparent,
                  width: 2,
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  /// ---------------- LAMINATION PICKER ----------------
  Widget _laminationPicker() {
    return SizedBox(
      height: 56,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: laminationList.length,
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemBuilder: (context, i) {
          final l = laminationList[i];
          final selected = _selectedLamination?["id"] == l["id"];

          return GestureDetector(
            onTap: () => setState(() => _selectedLamination = l),
            child: Container(
              width: 56,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: selected ? Colors.blue : Colors.transparent,
                  width: 2,
                ),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: Image.asset(l["image"], fit: BoxFit.cover),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget interiorExteriorToggle() {
    return ToggleSwitch(
      borderWidth: 1,
      borderColor: [Colors.black],
      minWidth: 75,
      minHeight: 20,
      cornerRadius: 5,
      totalSwitches: 2,
      labels: const ["Interior", "Exterior"],
      initialLabelIndex: _isInterior ? 0 : 1,

      /// COLORS
      activeBgColor: const [Colors.white],
      inactiveBgColor: const Color(0xFF2E2E2E),
      activeFgColor: Colors.black,
      inactiveFgColor: Colors.transparent,

      // 👈 hides unselected text
      radiusStyle: true,
      onToggle: (index) {
        setState(() {
          _isInterior = index == 0;
        });
      },
    );
  }
}
