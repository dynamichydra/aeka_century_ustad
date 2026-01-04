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
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
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

  @override
  void initState() {
    super.initState();
    _originalImage = widget.imageFile;
    _editedImage = widget.imageFile;

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
            Stack(
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

                        Text("AI Based Color & Pattern Search"),
                        SizedBox(height: 5),
                        const TTextField(
                          labelText: 'Search',
                          prefixIcon: Icon(
                            Icons.search,
                            color: TColors.darkerGrey,
                          ),
                          isCircularIcon: true,
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
                                color: _pickingColor
                                    ? Colors.blue
                                    : Colors.black,
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
                            InkWell(
                              onTap: () {
                                context.go("/");
                              },
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
                                  child: Icon(Icons.home, size: 24),
                                ),
                              ),
                            ),
                            SizedBox(
                              width: 180,
                              height: 50,
                              child: ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  padding: EdgeInsets.zero,
                                  shape: const RoundedRectangleBorder(
                                    borderRadius: BorderRadius.all(Radius.circular(20)),
                                  ),
                                ),
                                onPressed: () {
                                  if (_loading) return;

                                  if (_selectedColor == null || _selectedLamination == null) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text("Please select color and texture"),
                                      ),
                                    );
                                    return;
                                  }

                                  _applyAI();
                                },
                                child: _loading
                                    ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                                    : const Text(
                                  "Apply",
                                  style: TextStyle(fontWeight: FontWeight.w700),
                                ),
                              ),
                            ),


                            SizedBox(width: 50, height: 50),

                            // Portal(
                            //
                            //   child: PortalTarget(
                            //     visible: isOpen,
                            //     anchor: const Aligned(
                            //       follower: Alignment.bottomCenter,
                            //       target: Alignment.topCenter,
                            //     ),
                            //
                            //     portalFollower:  Stack(
                            //       children: [
                            //         /// 🔒 FULL SCREEN MODAL BARRIER
                            //         Positioned.fill(
                            //           child: GestureDetector(
                            //             behavior: HitTestBehavior.opaque,
                            //             onTap: () => setState(() => isOpen = false),
                            //             child: const SizedBox(),
                            //           ),
                            //         ),
                            //
                            //         /// 🔝 POPUP MENU (aligned above button)
                            //         Align(
                            //           alignment: Alignment.topCenter,
                            //           child: Transform.translate(
                            //             offset: const Offset(0, -12),
                            //             child: Material(
                            //               color: const Color(0xFFF1F1F1),
                            //               elevation: 12,
                            //               borderRadius: BorderRadius.circular(5),
                            //               child: Padding(
                            //                 padding: const EdgeInsets.all(5),
                            //                 child: Column(
                            //                   mainAxisSize: MainAxisSize.min,
                            //                   children: [
                            //                     IconButton(
                            //                       icon: Container(
                            //                           color: Colors.white,
                            //                           child: Padding(
                            //                             padding: const EdgeInsets.all(12.0),
                            //                             child: const Icon(Icons.share),
                            //                           )),
                            //                       onPressed: () {
                            //                         setState(() => print("object"));
                            //                       },
                            //                     ),
                            //                     IconButton(
                            //                       icon: Container(
                            //                           color: Colors.white,
                            //                           child: Padding(
                            //                             padding: const EdgeInsets.all(12.0),
                            //                             child: const Icon(Icons.bookmark),
                            //                           )),
                            //                       onPressed: () {
                            //                         setState(() => isOpen = false);
                            //                       },
                            //                     ),
                            //                   ],
                            //                 ),
                            //               ),
                            //             ),
                            //           ),
                            //         ),
                            //       ],
                            //     ),
                            //
                            //     child: GestureDetector(
                            //       onTap: () => setState(() => isOpen = !isOpen),
                            //       child: Container(
                            //         width: 50,
                            //         height: 50,
                            //         decoration: const BoxDecoration(
                            //           shape: BoxShape.circle,
                            //           color: Colors.white,
                            //           boxShadow: [
                            //             BoxShadow(blurRadius: 4, color: Colors.black26),
                            //           ],
                            //         ),
                            //         child: Icon(
                            //           isOpen ? Icons.close : Icons.more_horiz,
                            //           size: 32,
                            //         ),
                            //       ),
                            //     ),
                            //   ),
                            // ),
                          ],
                        ),
                        const SizedBox(height: 30),
                      ],
                    ),
                  ),
                ),

                // Custom App Button
                Positioned(
                  top: 40,
                  left: 0,
                  right: 0,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      IconButton(
                        icon: Icon(Iconsax.menu_1, color: Colors.black),
                        onPressed: () =>
                            _scaffoldKey.currentState?.openDrawer(),
                      ),
                      Padding(
                        padding: EdgeInsets.only(right: TSizes.defaultSpace),
                        child: Image(
                          image: AssetImage(TImages.smallLogo),
                          width: 30,
                          height: 30,
                        ),
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
              ],
            ),

            /// TAP BARRIER
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

                    // setState(() {
                    //   isOpen = false; // close popup after share
                    // });
                  },
                  onBookmark: () {
                    setState(() {
                      isBookmarkPopupOpen = true;
                    });
                  },
                ),
              ),

            // if (isBookmarkPopupOpen)
            //   Positioned.fill(
            //     child: Center(
            //       child: BookmarkPopup(
            //         onClose: () {
            //           setState(() {
            //             isBookmarkPopupOpen = false;
            //             isOpen = false;
            //           });
            //         },
            //       ),
            //     ),
            //   ),
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
            ]
,
            /// FLOATING BUTTON
            Positioned(
              right: 16,
              bottom: 54,
              child: GestureDetector(
                onTap: () => setState(() => isOpen = !isOpen),
                child: Container(
                  width: 56,
                  height: 56,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white,
                    boxShadow: [
                      BoxShadow(blurRadius: 6, color: Colors.black26),
                    ],
                  ),
                  child: Icon(
                    isOpen ? Icons.close : Icons.more_horiz,
                    size: 32,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// ---------------- COLOR PICKER ----------------
  Widget _colorPicker() {
    return SizedBox(
      height: 30,
      child: Stack(
        children: [
          /// 1️⃣ The horizontal list
          ListView.separated(
            controller: _colorScrollController,
            scrollDirection: Axis.horizontal,
            itemCount: colorList.length,
            padding: const EdgeInsets.only(right: 32),
            // space for arrow
            separatorBuilder: (_, __) => const SizedBox(width: 12),
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
                  width: 28,
                  alignment: Alignment.center,
                  decoration: const BoxDecoration(
                    // gradient: LinearGradient(
                    //   colors: [Colors.transparent, Colors.white],
                    //   begin: Alignment.centerLeft,
                    //   end: Alignment.centerRight,
                    // ),
                    color: Colors.white,
                  ),
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
            separatorBuilder: (_, __) => const SizedBox(width: 12),
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
                  // width: 36,
                  decoration: const BoxDecoration(
                    // gradient: LinearGradient(
                    //   colors: [Colors.transparent, Colors.white],
                    //   begin: Alignment.centerLeft,
                    //   end: Alignment.centerRight,
                    // ),
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
                  child: const Icon(Icons.share, ),
                )),
            onPressed: onShare,
          ),
          IconButton(
            icon: Container(
                color: Colors.white,
                child: Padding(
              padding: const EdgeInsets.all(8.0),
              child: const Icon(Icons.bookmark, ),
            )),
            onPressed: onBookmark,
          ),
        ],
      ),
    );
  }
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
