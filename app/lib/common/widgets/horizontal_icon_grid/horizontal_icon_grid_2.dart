import 'package:flutter/material.dart';

class HorizontalIconGrid extends StatefulWidget {
  final int itemCount;
  final Widget Function(BuildContext context, int index) itemBuilder;
  final Widget? viewMoreWidget;
  final VoidCallback? onViewMoreTap;

  const HorizontalIconGrid({
    super.key,
    required this.itemCount,
    required this.itemBuilder,
    this.viewMoreWidget,
    this.onViewMoreTap,
  });

  @override
  State<HorizontalIconGrid> createState() => _HorizontalIconGridState();
}

class _HorizontalIconGridState extends State<HorizontalIconGrid> {
  final ScrollController _scrollController = ScrollController();
  bool _canScrollRight = false;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_checkScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) => _checkScroll());
  }

  @override
  void didUpdateWidget(HorizontalIconGrid oldWidget) {
    super.didUpdateWidget(oldWidget);
    WidgetsBinding.instance.addPostFrameCallback((_) => _checkScroll());
  }

  @override
  void dispose() {
    _scrollController.removeListener(_checkScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _checkScroll() {
    if (!_scrollController.hasClients) return;
    final maxScroll = _scrollController.position.maxScrollExtent;
    final currentScroll = _scrollController.position.pixels;
    
    // Check if we can scroll right, with a small 5 pixel buffer
    final canScroll = maxScroll > 0 && currentScroll < maxScroll - 5;
    if (canScroll != _canScrollRight) {
      setState(() {
        _canScrollRight = canScroll;
      });
    }
  }

  void _handleViewMoreTap() {
    if (!_scrollController.hasClients) return;
    final maxScroll = _scrollController.position.maxScrollExtent;
    final currentScroll = _scrollController.position.pixels;
    
    // Scroll by the width of 4 items exactly
    final viewportWidth = _scrollController.position.viewportDimension;
    final offset = (currentScroll + viewportWidth * 0.8).clamp(0.0, maxScroll);

    _scrollController.animateTo(
      offset,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // Show exactly 4 elements + View More space (5 items total)
        final itemWidth = constraints.maxWidth / 5;

        return Stack(
          children: [
            ListView.builder(
              controller: _scrollController,
              padding: EdgeInsets.zero,
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              itemCount: widget.itemCount,
              itemBuilder: (context, index) {
                return SizedBox(
                  width: itemWidth,
                  child: widget.itemBuilder(context, index),
                );
              },
            ),
            
            if (widget.viewMoreWidget != null &&
                (widget.onViewMoreTap != null || _canScrollRight))
              Positioned(
                right: 0,
                top: 0,
                bottom: 0,
                child: GestureDetector(
                  onTap: widget.onViewMoreTap ?? _handleViewMoreTap,
                  child: Container(
                    width: itemWidth,
                    alignment: Alignment.topCenter,
                    color: Colors.white, // solid background to hide the scrolled items beneath
                    child: IgnorePointer(
                      child: widget.viewMoreWidget,
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}