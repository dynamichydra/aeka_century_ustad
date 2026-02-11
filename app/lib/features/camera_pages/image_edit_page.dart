import 'dart:io';
import 'dart:typed_data';

// import 'package:century_ai/features/ai_image/image_edit_page.dart';
import 'package:century_ai/common/widgets/inputs/text_field.dart';
import 'package:century_ai/features/camera_pages/widgets/ImageCompareSlider.dart';
import 'package:century_ai/features/home/screens/widgets/home_drawer.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:iconsax/iconsax.dart';
import 'package:century_ai/utils/constants/image_strings.dart';
import 'package:century_ai/utils/constants/colors.dart';
import 'dummy_data.dart';
import 'package:century_ai/utils/api/gemini_image_service.dart';
import 'package:century_ai/utils/methods/temp_img_converter.dart';
import 'package:century_ai/utils/constants/sizes.dart';
import 'dart:ui' as ui;
import 'package:flutter/rendering.dart';
import 'package:flutter_portal/flutter_portal.dart';
import 'package:share_plus/share_plus.dart';

class ImageEditPage extends StatefulWidget {
  final File imageFile;
  final Color? pickedColor;

  const ImageEditPage({super.key, required this.imageFile, this.pickedColor});

  @override
  State<ImageEditPage> createState() => _ImageEditPageState();
}

class _ImageEditPageState extends State<ImageEditPage> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final GlobalKey _screenKey = GlobalKey();
  bool _pickingColor = false;
  ui.Image? _screenImage;
  ByteData? _pixelData;
  final Offset _touchPos = Offset.zero;
  Color _pickedColor = Colors.transparent;
  bool _showComparison = false;

  bool _isInterior = true;
  final List<File> _savedVersions = [];
  int? _comparingIndex;

  // Track indices for comparison halves
  int _leftIndex = -1; // -1 for original image
  int _rightIndex = 0; // Index in _savedVersions for right side
  double _comparePos = 0.5;

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

  final ScrollController _colorScrollController = ScrollController();
  final ScrollController _laminationScrollController = ScrollController();

  bool _showColorArrow = false;
  bool _showLaminationArrow = false;

  void _checkOverflow({
    required ScrollController controller,
    required void Function(bool) setVisible,
  }) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!controller.hasClients) return;

      final maxScroll = controller.position.maxScrollExtent;
      setState(() => setVisible(maxScroll > 0));
    });
  }
  final List<bool> _isSelected = [true, false];

  @override
  void initState() {
    super.initState();
    _originalImage = widget.imageFile;
    _editedImage = widget.imageFile;

    if (widget.pickedColor != null) {
      _pickedColor = widget.pickedColor!;
      _pickingColor = true;
    }

    _checkOverflow(
      controller: _colorScrollController,
      setVisible: (v) => _showColorArrow = v,
    );

    _checkOverflow(
      controller: _laminationScrollController,
      setVisible: (v) => _showLaminationArrow = v,
    );
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
      if (result != null) {
        _savedVersions.add(result);
        _comparingIndex = _savedVersions.length - 1;
        _rightIndex = _savedVersions.length - 1;
      }
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

  bool isOpen = false;
  bool isBookmarkPopupOpen = false;

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      key: _screenKey,
      child: Scaffold(
        key: _scaffoldKey,
        drawer: const HomeDrawer(),
        backgroundColor: Colors.white,
        body: Stack(
          children: [
            Column(
              children: [
                /// ---------------- IMAGE AREA ----------------
                SafeArea(
                  child: Builder(
                      builder: (context) {
                        final imageAreaHeight = MediaQuery.of(context).size.height * 0.40;
                        return SizedBox(
                          height: imageAreaHeight,
                          child: Stack(
                            children: [
                              Positioned.fill(
                                child: (_showComparison && _savedVersions.isNotEmpty)
                                    ? LayoutBuilder(
                                    builder: (context, constraints) {
                                      final width = constraints.maxWidth;
                                      return Stack(
                                        children: [
                                          ImageCompareSlider(
                                            before: _leftIndex == -1 ? _originalImage! : _savedVersions[_leftIndex],
                                            after: _savedVersions[_rightIndex.clamp(0, _savedVersions.length - 1)],
                                            height: imageAreaHeight,
                                            position: _comparePos,
                                            onChanged: (val) => setState(() => _comparePos = val),
                                          ),

                                          /// ---------------- IMAGE OVERLAY CONTROLS ----------------
                                          // TOP-RIGHT of Left Image (X)
                                          Positioned(
                                            top: 10,
                                            left: (width * _comparePos) - 34,
                                            child: _buildSmallRoundButton(
                                              icon: Icons.close,
                                              onTap: () => setState(() => _showComparison = false),
                                              size: 24,
                                              iconSize: 14,
                                            ),
                                          ),

                                          // TOP-RIGHT of Right Image (X)
                                          Positioned(
                                            top: 10,
                                            right: 10,
                                            child: _buildSmallRoundButton(
                                              icon: Icons.close,
                                              onTap: () => setState(() => _showComparison = false),
                                              size: 24,
                                              iconSize: 14,
                                            ),
                                          ),

                                          // BOTTOM-LEFT CONTROLS (for Before image)
                                          Positioned(
                                            bottom: 10,
                                            left: 10,
                                            child: Row(
                                              children: [
                                                _buildImageControlCircle(
                                                  icon: Icons.swap_horiz,
                                                  onTap: () {
                                                    setState(() {
                                                      _leftIndex++;
                                                      if (_leftIndex >= _savedVersions.length) {
                                                        _leftIndex = -1; // Cycle back to original
                                                      }
                                                    });
                                                  },
                                                ),
                                                const SizedBox(width: 8),
                                                _buildImageControlCircle(
                                                  icon: Icons.check,
                                                  onTap: () => _finalizeImage(_leftIndex == -1 ? _originalImage! : _savedVersions[_leftIndex]),
                                                ),
                                              ],
                                            ),
                                          ),

                                          // BOTTOM-RIGHT CONTROLS (for After image)
                                          Positioned(
                                            bottom: 10,
                                            right: 10,
                                            child: Row(
                                              children: [
                                                _buildImageControlCircle(
                                                  icon: Icons.swap_horiz,
                                                  onTap: () {
                                                    setState(() {
                                                      _rightIndex++;
                                                      if (_rightIndex >= _savedVersions.length) {
                                                        _rightIndex = 0;
                                                      }
                                                    });
                                                  },
                                                ),
                                                const SizedBox(width: 8),
                                                _buildImageControlCircle(
                                                  icon: Icons.check,
                                                  onTap: () => _finalizeImage(_savedVersions[_rightIndex]),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ],
                                      );
                                    }
                                )
                                    : Image.file(
                                  (_showComparison && _comparingIndex != null && _savedVersions.isNotEmpty)
                                      ? _savedVersions[_comparingIndex!]
                                      : _originalImage!,
                                  fit: BoxFit.cover,
                                  width: double.infinity,
                                ),
                              ),


                              // Compare Button Pill (Conditional, hide if comparison is active to avoid clutter)
                              if (!_showComparison || _savedVersions.isEmpty)
                                Positioned(
                                  bottom: 16,
                                  right: 16,
                                  child: GestureDetector(
                                    onTap: () async {
                                      if (_loading) return;
                                      if (_savedVersions.isEmpty) {
                                        if (_selectedColor == null || _selectedLamination == null) {
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            const SnackBar(content: Text("Select color and texture first.")),
                                          );
                                          return;
                                        }
                                        await _applyAI();
                                        setState(() => _showComparison = true);
                                      } else {
                                        setState(() => _showComparison = !_showComparison);
                                      }
                                    },
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                      decoration: BoxDecoration(
                                        color: Colors.white.withOpacity(0.9),
                                        borderRadius: BorderRadius.circular(20),
                                        boxShadow: [
                                          BoxShadow(
                                            color: Colors.black.withOpacity(0.1),
                                            blurRadius: 4,
                                            offset: const Offset(0, 2),
                                          ),
                                        ],
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          if (_loading)
                                            const SizedBox(
                                              width: 14,
                                              height: 14,
                                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black),
                                            )
                                          else
                                            Icon(
                                              _showComparison ? Icons.close : Iconsax.frame_1,
                                              size: 18,
                                              color: Colors.black,
                                            ),
                                          const SizedBox(width: 6),
                                          Text(
                                            _loading
                                                ? "Generating..."
                                                : (_showComparison ? "Close" : "Compare"),
                                            style: const TextStyle(
                                              color: Colors.black,
                                              fontWeight: FontWeight.w600,
                                              fontSize: 12,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        );
                      }
                  ),
                ),

                /// ---------------- SAVED VERSIONS LIST ----------------
                if (_savedVersions.isNotEmpty)
                  Container(
                    height: 48,
                    padding: EdgeInsets.zero,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: _savedVersions.length,
                      separatorBuilder: (context, index) => const SizedBox(width: 12),
                      itemBuilder: (context, index) {
                        final isSelected = _comparingIndex == index;
                        return Center(
                            child: GestureDetector(
                              onTap: () {
                                setState(() {
                                  _comparingIndex = index;
                                  _showComparison = true;
                                });
                              },
                              child:
                              Container(
                                width: 44,
                                height: 44,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: isSelected ? Colors.black : Colors.transparent,
                                    width: 2,
                                  ),
                                ),
                                child: Padding(
                                  padding: const EdgeInsets.all(2.0),
                                  child: ClipOval(
                                    child: Image.file(
                                      _savedVersions[index],
                                      fit: BoxFit.cover,
                                    ),
                                  ),
                                ),
                              ),
                            )
                        );
                      },
                    ),
                  ),

                /// ---------------- BOTTOM PANEL ----------------
                Expanded(
                  child: SingleChildScrollView(
                    child: Container(
                      padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                      decoration: const BoxDecoration(
                        color: Colors.white,
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 8),
                          const Text(
                            "Design",
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 24,
                            ),
                          ),
                          Row(
                            children: [
                              const Expanded(
                                child: Text(
                                  "AI Based Color & Pattern Search",
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                              ToggleButtons(
                                isSelected: _isSelected,
                                onPressed: (index) {
                                  setState(() {
                                    for (int i = 0; i < _isSelected.length; i++) {
                                      _isSelected[i] = i == index;
                                    }
                                  });
                                },
                                borderRadius: BorderRadius.circular(8),
                                constraints: const BoxConstraints(
                                  minHeight: 24,
                                  minWidth: 56,
                                ),
                                selectedColor: Colors.black,
                                fillColor: const Color(0xff808080),
                                color: const Color(0xFFA3A1A1),
                                children: const [
                                  Text("Interior"),
                                  Text("Exterior"),
                                ],
                              ),
                            ],
                          ),
                          const SizedBox(height: 5),
                          const TTextField(
                            labelText: 'Search',
                            prefixIcon: Icon(
                              Icons.search,
                              color: TColors.darkGray,
                            ),
                            isCircularIcon: true,
                          ),
                          const SizedBox(height: 5),
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
                                  context.pushReplacement("/camera", extra: {
                                    'fromColorPicker': true,
                                    'originalImage': widget.imageFile,
                                  });
                                },
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          _colorPicker(),
                          const SizedBox(height: 16),
                          const Text(
                            "Pattern & Texture",
                            style: TextStyle(fontWeight: FontWeight.w600),
                          ),
                          const SizedBox(height: 8),
                          _laminationPicker(),
                          const SizedBox(height: 20),
                          Row(
                            children: [
                              // Bookmark Button
                              InkWell(
                                onTap: () {
                                  setState(() {
                                    isBookmarkPopupOpen = true;
                                  });
                                },
                                child: Container(
                                  width: 50,
                                  height: 50,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: Colors.white,
                                    boxShadow: [
                                      BoxShadow(
                                        blurRadius: 3,
                                        color: const Color(0xFF646464),
                                        offset: const Offset(0, 2),
                                      ),
                                    ],
                                  ),
                                  child: const Center(
                                    child: Icon(Icons.bookmark, size: 24),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),

                              // Apply Button
                              Expanded(
                                child: SizedBox(
                                  height: 50,
                                  child: ElevatedButton(
                                    style: ElevatedButton.styleFrom(
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(20),
                                      ),
                                      padding: const EdgeInsets.symmetric(horizontal: 16),
                                    ),
                                    onPressed: () async {
                                      if (_loading) return;

                                      // If selection is incomplete, show snackbar
                                      if (_selectedColor == null || _selectedLamination == null) {
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          const SnackBar(content: Text("Please select both color and texture.")),
                                        );
                                        return;
                                      }

                                      // Complete selection: Apply AI
                                      await _applyAI();
                                    },
                                    child: FittedBox(
                                      child: Text(
                                        _loading ? "Generating..." : "Apply",
                                        style: const TextStyle(fontWeight: FontWeight.w700),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),

                              // Share Button
                              InkWell(
                                onTap: () {
                                  Share.share(
                                    'Check out this design!',
                                    subject: 'Furniture Design',
                                  );
                                },
                                child: Container(
                                  width: 50,
                                  height: 50,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: Colors.white,
                                    boxShadow: [
                                      BoxShadow(
                                        blurRadius: 3,
                                        color: const Color(0xFF646464),
                                        offset: const Offset(0, 2),
                                      ),
                                    ],
                                  ),
                                  child: const Center(
                                    child: Icon(Icons.share, size: 24),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),

                              // Proceed/Forward Arrow
                              InkWell(
                                onTap: () {
                                  final currentIdx = _rightIndex.clamp(0, _savedVersions.length - 1);
                                  _finalizeImage(_savedVersions.isNotEmpty ? _savedVersions[currentIdx] : _originalImage!);
                                },
                                child: Container(
                                  width: 50,
                                  height: 50,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: Colors.white,
                                    boxShadow: [
                                      BoxShadow(
                                        blurRadius: 3,
                                        color: const Color(0xFF646464),
                                        offset: const Offset(0, 2),
                                      ),
                                    ],
                                  ),
                                  child: const Center(
                                    child: Icon(Icons.arrow_forward, size: 24),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 30),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),

            // Top Buttons (Menu & Logo)
            Positioned(
              top: 40,
              left: 16,
              right: 16,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(
                    icon: const Icon(Iconsax.menu_1, color: Colors.black),
                    onPressed: () => _scaffoldKey.currentState?.openDrawer(),
                  ),
                  Image(
                    image: AssetImage(TImages.smallLogo),
                    width: 30,
                    height: 30,
                  ),
                ],
              ),
            ),

            if (_pickingColor)
              Positioned(
                left: _touchPos.dx - 18,
                top: _touchPos.dy - 48,
                child: Container(
                  width: 18,
                  height: 18,
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

            /// TAP BARRIER for Share Popup
            if (isOpen)
              Positioned.fill(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => setState(() => isOpen = false),
                  child: const SizedBox(),
                ),
              ),

            /// POPUP BAR
            if (isOpen)
              Positioned(
                right: 18,
                bottom: 120, // 👈 ABOVE BUTTON
                child: CustomPopupBar(
                  onShare: () {
                    Share.share(
                      'Check out this design!',
                      subject: 'Furniture Design',
                    );
                  },
                  onBookmark: () {
                    setState(() {
                      isBookmarkPopupOpen = true;
                    });
                  },
                ),
              ),

            if (isBookmarkPopupOpen) ...[
              /// 🔒 TAP BARRIER (behind popup)
              Positioned.fill(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () {
                    setState(() {
                      isBookmarkPopupOpen = false;
                      isOpen = false;
                    });
                  },
                  child: const SizedBox(),
                ),
              ),

              /// 📌 BOOKMARK POPUP (above barrier)
              Positioned.fill(
                child: Center(
                  child: BookmarkPopup(
                    onClose: () {
                      setState(() {
                        isBookmarkPopupOpen = false;
                        isOpen = false;
                      });
                    },
                  ),
                ),
              ),
            ],

          ],
        ),
      ),
    );
  }

  Widget _colorPicker() {
    return SizedBox(
      height: 30,
      child: Stack(
        children: [
          ListView.separated(
            controller: _colorScrollController,
            scrollDirection: Axis.horizontal,
            itemCount: colorList.length,
            padding: const EdgeInsets.only(right: 32),
            separatorBuilder: (_, _) => const SizedBox(width: 12),
            itemBuilder: (context, i) {
              final c = colorList[i];
              final selected = _selectedColor?["id"] == c["id"];

              return GestureDetector(
                onTap: () => setState(() => _selectedColor = c),
                child: Container(
                  width: selected ? 26 : 28,
                  height: selected ? 26 : 28,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: hexToColor(c["hex"]),
                    border: Border.all(
                      color: selected
                          ? hexToColor(c["hex"])
                          : Colors.transparent,
                      width: 2,
                    ),
                  ),

                  child: selected
                      ? Container(
                    width: 25,
                    height: 25,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: hexToColor(c["hex"]),
                      border: Border.all(
                        color: selected
                            ? Colors.white
                            : Colors.transparent,
                        width: 2,
                      ),
                    ),
                  )
                      : null,
                ),
              );
            },
          ),
          /// 2️⃣ RIGHT ARROW OVERLAY
          if (_showColorArrow)
            Positioned(
              right: 0,
              top: 0,
              bottom: 0,
              child: InkWell(
                onTap: () {
                  _colorScrollController.animateTo(
                    _colorScrollController.position.pixels + 80,
                    duration: const Duration(milliseconds: 200),
                    curve: Curves.easeOut,
                  );
                },
                child: Container(
                  width: 15,
                  alignment: Alignment.center,
                  child: const Icon(Icons.chevron_right, size: 22),
                ),
              ),
            ),
        ],
      ),
    );
  }

  /// ---------------- LAMINATION PICKER ----------------
  Widget _laminationPicker() {
    return SizedBox(
      height: 36,
      child: Stack(
        children: [
          ListView.separated(
            controller: _laminationScrollController,
            scrollDirection: Axis.horizontal,
            itemCount: laminationList.length,
            padding: const EdgeInsets.only(right: 36),
            separatorBuilder: (_, _) => const SizedBox(width: 12),
            itemBuilder: (context, i) {
              final l = laminationList[i];
              final selected = _selectedLamination?["id"] == l["id"];

              return GestureDetector(
                onTap: () => setState(() => _selectedLamination = l),
                child: Container(
                  width: 36,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(5),
                    border: Border.all(
                      color: selected ? Colors.blue : Colors.transparent,
                      width: 2,
                    ),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(3),
                    child: Image.asset(l["image"], fit: BoxFit.cover),
                  ),
                ),
              );
            },
          ),

          /// 👉 Right Arrow
          if (_showLaminationArrow)
            Positioned(
              right: 0,
              top: 0,
              bottom: 0,
              child: GestureDetector(
                onTap: () {
                  _laminationScrollController.animateTo(
                    _laminationScrollController.position.pixels + 100,
                    duration: const Duration(milliseconds: 200),
                    curve: Curves.easeOut,
                  );
                },
                child: Container(
                  decoration: const BoxDecoration(
                    color: Colors.white,
                  ),
                  child: const Icon(Icons.chevron_right),
                ),
              ),
            ),
        ],
      ),
    );
  }

  void _finalizeImage(File image) {
    context.push("/image_finalize", extra: {
      'editedImage': image,
      'selectedColor': _selectedColor,
      'selectedLamination': _selectedLamination,
    });
  }

  Widget _buildSmallRoundButton({
    required IconData icon,
    required VoidCallback onTap,
    double size = 30,
    double iconSize = 18,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.8),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, size: iconSize, color: Colors.black),
      ),
    );
  }

  Widget _buildImageControlCircle({
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.2),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Icon(icon, size: 20, color: Colors.black),
      ),
    );
  }
}

class CustomPopupBar extends StatelessWidget {
  final VoidCallback onShare;
  final VoidCallback onBookmark;

  const CustomPopupBar({
    super.key,
    required this.onShare,
    required this.onBookmark,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      elevation: 12,
      borderRadius: BorderRadius.circular(10),
      color: Color(0xffF3F3F3), // 🔴 RED BACKGROUND
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: Container(
              color: Colors.white,
              child: Padding(
                padding: const EdgeInsets.all(8.0),
                child: const Icon(Icons.share),
              ),
            ),
            onPressed: onShare,
          ),
          IconButton(
            icon: Container(
              color: Colors.white,
              child: Padding(
                padding: const EdgeInsets.all(8.0),
                child: const Icon(Icons.bookmark),
              ),
            ),
            onPressed: onBookmark,
          ),
        ],
      ),
    );
  }
}

Color hexToColor(String hex) {
  hex = hex.replaceAll("#", "");
  return Color(int.parse("FF$hex", radix: 16));
}

class BookmarkPopup extends StatefulWidget {
  final VoidCallback onClose;

  const BookmarkPopup({super.key, required this.onClose});

  @override
  State<BookmarkPopup> createState() => _BookmarkPopupState();
}

final TextEditingController folderController = TextEditingController();

class _BookmarkPopupState extends State<BookmarkPopup> {
  final Map<String, bool> folders = {
    "Bed Room": false,
    "Living Room": false,
    "Folder 1": false,
    "Study Room": false,
    "Kitchen Room": false,
    "Folder 2": false,
  };

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.all(30),
      child: Material(
        elevation: 16,
        borderRadius: BorderRadius.circular(12),
        color: const Color(0xffF3F3F3),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                "Save to",
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
              ),

              const SizedBox(height: 8),

              TextField(
                controller: folderController,
                decoration: InputDecoration(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 8),
                  border: const OutlineInputBorder(
                    borderRadius: BorderRadius.zero,
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(5),
                    borderSide: const BorderSide(color: Colors.grey),
                  ),
                  focusedBorder: const OutlineInputBorder(
                    borderRadius: BorderRadius.zero,
                    borderSide: BorderSide(color: Colors.blue, width: 2),
                  ),
                ),
              ),

              const SizedBox(height: 12),

              /// ✅ CHECKBOX GRID (CLICKABLE)
              GridView.count(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisCount: 2,
                mainAxisSpacing: 6,
                crossAxisSpacing: 12,
                childAspectRatio: 4,
                children: folders.keys.map((key) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: Row(
                      children: [
                        Checkbox(
                          value: folders[key],
                          onChanged: (val) {
                            setState(() {
                              // Optional: single select behavior
                              folders.updateAll((key, value) => false);

                              folders[key] = val ?? false;

                              // Put selected folder into TextField
                              if (val == true) {
                                folderController.text = key;
                              } else {
                                folderController.clear();
                              }
                            });
                          },
                        ),
                        Expanded(
                          child: Text(
                            key,
                            style: const TextStyle(fontSize: 14),
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),

              const SizedBox(height: 8),

              const Center(child: Text("Or, Create A New Folder")),

              const SizedBox(height: 8),

              TextField(
                textAlign: TextAlign.center,
                decoration: InputDecoration(
                  hintText: "Enter Folder Name",
                  contentPadding: const EdgeInsets.symmetric(vertical: 10),
                  border: const OutlineInputBorder(
                    borderRadius: BorderRadius.zero,
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(5),
                    borderSide: const BorderSide(color: Colors.grey),
                  ),
                ),
              ),

              const SizedBox(height: 12),

              Center(
                child: SizedBox(
                  width: 100,
                  height: 36,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      padding: EdgeInsets.zero,
                      shape: const RoundedRectangleBorder(
                        borderRadius: BorderRadius.zero,
                      ),
                    ),
                    onPressed: () {
                      debugPrint("Selected folders: $folders");
                      widget.onClose();
                    },
                    child: const Text(
                      "Save",
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
class ExpandingToggleSwitch extends StatefulWidget {
  final List<String> items;
  final ValueChanged<int> onChanged;
  final double height;
  final double borderRadius;

  const ExpandingToggleSwitch({
    super.key,
    required this.items,
    required this.onChanged,
    this.height = 24, // 👈 smaller
    this.borderRadius = 8,
  }) : assert(items.length == 2);

  @override
  State<ExpandingToggleSwitch> createState() => _ExpandingToggleSwitchState();
}

class _ExpandingToggleSwitchState extends State<ExpandingToggleSwitch> {
  int selectedIndex = 0;

  static const Color selectedColor = Color(0x0ff8a660);
  static const Color unselectedColor = Color(0xFFA3A1A1);

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: widget.height,
      child: Row(
        children: List.generate(2, (index) {
          final bool isSelected = selectedIndex == index;

          return Expanded(
            flex: isSelected ? 4 : 1,
            child: GestureDetector(
              onTap: () {
                if (selectedIndex == index) return;
                setState(() => selectedIndex = index);
                widget.onChanged(index);
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeOutCubic,
                margin: const EdgeInsets.symmetric(horizontal: 2),
                decoration: BoxDecoration(
                  color: isSelected ? selectedColor : unselectedColor,
                  borderRadius:
                  BorderRadius.circular(widget.borderRadius),
                ),
                alignment: Alignment.center,
                child: AnimatedOpacity(
                  duration: const Duration(milliseconds: 150),
                  opacity: isSelected ? 1 : 0,
                  child: isSelected
                      ? Text(
                    widget.items[index],
                    style: const TextStyle(
                      fontSize: 12, // 👈 smaller text
                      fontWeight: FontWeight.w600,
                      color: Colors.black,
                    ),
                  )
                      : const SizedBox.shrink(),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }
}