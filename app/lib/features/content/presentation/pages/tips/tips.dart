import 'package:century_ai/core/constants/colors.dart';
import 'package:century_ai/core/constants/image_strings.dart';
import 'package:flutter/material.dart';

class TipsScreen extends StatelessWidget {
  const TipsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar:AppBar(
        title: const Text(
          'Tips',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const SizedBox(height: 40),
              const Text(
                'Tips to capture\nbest images',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 26, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 24),
              _PillLabel(text: "Do’s"),
              const SizedBox(height: 20),
              _ImageCard(
                width: double.infinity,
                height: 140,
                caption:
                    'Capture clear images in good lighting for accurate results.',
              ),
              const SizedBox(height: 28),
              _PillLabel(text: "Don’t"),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: const [
                  _SmallImageCard(text: 'Avoid blurry shots'),
                  _SmallImageCard(text: 'Avoid dim lighting'),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// ---------- Widgets ----------

class _PillLabel extends StatelessWidget {
  final String text;
  const _PillLabel({required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      decoration: BoxDecoration(
        color: TColors.lightGray,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: Colors.black87,
        ),
      ),
    );
  }
}

class _ImageCard extends StatelessWidget {
  final double width;
  final double height;
  final String caption;

  const _ImageCard({
    required this.width,
    required this.height,
    required this.caption,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: width,
          height: height,
          child: Image.asset(
            TImages.blankImageFull,
          )
        ),
        const SizedBox(height: 10),
        Text(
          caption,
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
        ),
      ],
    );
  }
}

class _SmallImageCard extends StatelessWidget {
  final String text;
  const _SmallImageCard({required this.text});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: (MediaQuery.of(context).size.width - 72) / 2,
      child: Column(
        children: [
          Container(
            height: 110,
            child: Image.asset(
              TImages.blankImage,
            )
          ),
          const SizedBox(height: 8),
          Text(
            text,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
          ),
        ],
      ),
    );
  }
}
