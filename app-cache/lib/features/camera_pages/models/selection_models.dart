import 'dart:ui';

class SelectionRect {
  double left;
  double top;
  double width;
  double height;

  SelectionRect({
    required this.left,
    required this.top,
    required this.width,
    required this.height,
  });

  Rect get rect => Rect.fromLTWH(left, top, width, height);
}

enum SelectionMode {
  none,
  creating,
  moving,
  resizeTopLeft,
  resizeTopRight,
  resizeBottomLeft,
  resizeBottomRight,
  resizeLeft,
  resizeRight,
  resizeTop,
  resizeBottom,
}
