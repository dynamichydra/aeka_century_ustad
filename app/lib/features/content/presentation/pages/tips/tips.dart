import 'package:century_ai/core/constants/colors.dart';
import 'package:century_ai/core/constants/image_strings.dart';
import 'package:century_ai/data/models/tip_model.dart';
import 'package:century_ai/data/repositories/tips_repository.dart';
import 'package:century_ai/data/services/api_service.dart';
import 'package:flutter/material.dart';

class TipsScreen extends StatefulWidget {
  const TipsScreen({super.key});

  @override
  State<TipsScreen> createState() => _TipsScreenState();
}

class _TipsScreenState extends State<TipsScreen> {
  late final TipsRepository _tipsRepository;
  List<TipModel> _tips = const <TipModel>[];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _tipsRepository = TipsRepository(ApiService());
    _loadTips();
  }

  Future<void> _loadTips() async {
    final tips = await _tipsRepository.getTips(limit: 6);
    if (!mounted) return;
    setState(() {
      _tips = tips;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final doTip = _tips.isNotEmpty
        ? _tips.first
        : const TipModel(
            id: 'fallback-do',
            title: 'Capture clear images',
            body: 'Capture clear images in good lighting for accurate results.',
          );
    final dontTip1 = _tips.length > 1 ? _tips[1] : doTip;
    final dontTip2 = _tips.length > 2 ? _tips[2] : doTip;

    return Scaffold(
      appBar: AppBar(
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
              if (_isLoading)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  child: CircularProgressIndicator(),
                ),
              const SizedBox(height: 24),
              const _PillLabel(text: "Do's"),
              const SizedBox(height: 20),
              _ImageCard(
                width: double.infinity,
                height: 140,
                caption: doTip.body,
              ),
              const SizedBox(height: 28),
              const _PillLabel(text: "Don't"),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _SmallImageCard(text: dontTip1.title),
                  _SmallImageCard(text: dontTip2.title),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

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
        SizedBox(
          width: width,
          height: height,
          child: Image.asset(TImages.blankImageFull),
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
          SizedBox(
            height: 110,
            child: Image.asset(TImages.blankImage),
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
