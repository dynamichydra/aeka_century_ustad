import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;

class SimpleCropPage extends StatefulWidget {
  final File imageFile;

  const SimpleCropPage({super.key, required this.imageFile});

  @override
  State<SimpleCropPage> createState() => _SimpleCropPageState();
}

class _SimpleCropPageState extends State<SimpleCropPage> {
  Rect _cropRect = const Rect.fromLTWH(60, 120, 260, 260);
  Size? _renderSize;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: LayoutBuilder(
        builder: (context, constraints) {
          _renderSize = Size(constraints.maxWidth, constraints.maxHeight);

          return Stack(
            children: [
              Positioned.fill(
                child: Image.file(widget.imageFile, fit: BoxFit.contain),
              ),

              _CropBox(
                parentSize: _renderSize!,
                rect: _cropRect,
                onChanged: (r) => setState(() => _cropRect = r),
              ),

              Positioned(
                bottom: 40,
                left: 0,
                right: 0,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text(
                        "Retake",
                        style: TextStyle(color: Colors.white),
                      ),
                    ),
                    ElevatedButton(
                      onPressed: _applyCrop,
                      child: const Text("Apply"),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _applyCrop() async {
    final bytes = await widget.imageFile.readAsBytes();
    final decoded = img.decodeImage(bytes)!;

    final scaleX = decoded.width / _renderSize!.width;
    final scaleY = decoded.height / _renderSize!.height;

    final crop = img.copyCrop(
      decoded,
      x: (_cropRect.left * scaleX).toInt(),
      y: (_cropRect.top * scaleY).toInt(),
      width: (_cropRect.width * scaleX).toInt(),
      height: (_cropRect.height * scaleY).toInt(),
    );

    final file = File(widget.imageFile.path)
      ..writeAsBytesSync(img.encodeJpg(crop));

    Navigator.pop(context, file);
  }
}

class _CropBox extends StatelessWidget {
  final Size parentSize;
  final Rect rect;
  final ValueChanged<Rect> onChanged;

  static const double minSize = 100;
  static const double edgeSize = 24;

  const _CropBox({
    required this.parentSize,
    required this.rect,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Positioned.fromRect(
      rect: rect,
      child: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onPanUpdate: (d) {
          final moved = rect.shift(d.delta);
          onChanged(_clamp(moved));
        },
        child: Stack(
          children: [
            Container(
              decoration: BoxDecoration(
                border: Border.all(color: Colors.white, width: 2),
              ),
            ),

            _edge(Alignment.centerLeft, (d) {
              onChanged(_resize(left: d.delta.dx));
            }),
            _edge(Alignment.centerRight, (d) {
              onChanged(_resize(right: d.delta.dx));
            }),
            _edge(Alignment.topCenter, (d) {
              onChanged(_resize(top: d.delta.dy));
            }),
            _edge(Alignment.bottomCenter, (d) {
              onChanged(_resize(bottom: d.delta.dy));
            }),
          ],
        ),
      ),
    );
  }

  Widget _edge(Alignment a, void Function(DragUpdateDetails) onDrag) {
    return Align(
      alignment: a,
      child: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onPanUpdate: onDrag,
        child: SizedBox(
          width: a.x == 0 ? double.infinity : edgeSize,
          height: a.y == 0 ? double.infinity : edgeSize,
        ),
      ),
    );
  }

  Rect _resize({
    double left = 0,
    double right = 0,
    double top = 0,
    double bottom = 0,
  }) {
    final r = Rect.fromLTRB(
      rect.left + left,
      rect.top + top,
      rect.right + right,
      rect.bottom + bottom,
    );

    if (r.width < minSize || r.height < minSize) return rect;
    return _clamp(r);
  }

  Rect _clamp(Rect r) {
    return Rect.fromLTWH(
      r.left.clamp(0, parentSize.width - r.width),
      r.top.clamp(0, parentSize.height - r.height),
      r.width,
      r.height,
    );
  }
}
