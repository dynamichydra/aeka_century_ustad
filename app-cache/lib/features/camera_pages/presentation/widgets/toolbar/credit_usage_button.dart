import 'package:century_ai/core/constants/colors.dart';
import 'package:century_ai/core/constants/final_save_credits.dart';
import 'package:flutter/material.dart';

class CreditUsageButton extends StatelessWidget {
  const CreditUsageButton({super.key, required this.used});

  final int? used;

  @override
  Widget build(BuildContext context) {
    const limit = FinalSaveCredits.limit;
    final remaining = used == null ? null : limit - used!;
    final description = remaining == null
        ? 'Final save credits'
        : '$remaining of $limit final save credits remaining';
    return IconButton(
      tooltip: description,
      padding: EdgeInsets.zero,
      style: IconButton.styleFrom(backgroundColor: Colors.white),
      onPressed: () => showCreditUsageDialog(context, used),
      icon: ExcludeSemantics(
        child: SizedBox.square(
          dimension: 44,
          child: Stack(
            alignment: Alignment.center,
            children: [
              Positioned.fill(
                child: TweenAnimationBuilder<double>(
                  tween: Tween(end: (used ?? 0) / limit),
                  duration: MediaQuery.disableAnimationsOf(context)
                      ? Duration.zero
                      : const Duration(milliseconds: 260),
                  builder: (context, value, _) => CircularProgressIndicator(
                    value: value,
                    strokeWidth: 3,
                    strokeCap: StrokeCap.round,
                    backgroundColor: const Color(0xFFE6E6E6),
                    color: TColors.vividRed,
                  ),
                ),
              ),
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.toll_outlined,
                      size: 15,
                      color: TColors.pureBlack,
                    ),
                    Text(
                      remaining?.toString() ?? '…',
                      style: const TextStyle(
                        fontSize: 12,
                        height: 1.15,
                        fontWeight: FontWeight.w700,
                        color: TColors.pureBlack,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

Future<void> showCreditUsageDialog(BuildContext context, int? used) =>
    showDialog<void>(
      context: context,
      builder: (_) => _CreditUsageDialog(used: used),
    );

class _CreditUsageDialog extends StatefulWidget {
  const _CreditUsageDialog({required this.used});

  final int? used;

  @override
  State<_CreditUsageDialog> createState() => _CreditUsageDialogState();
}

class _CreditUsageDialogState extends State<_CreditUsageDialog> {
  bool _showRemaining = false;

  @override
  Widget build(BuildContext context) {
    const limit = FinalSaveCredits.limit;
    final used = widget.used;
    final count = used == null ? 0 : (_showRemaining ? limit - used : used);
    final percentage = (100 * count / limit).round();
    final label = _showRemaining ? 'remaining' : 'used';
    return AlertDialog(
      scrollable: true,
      backgroundColor: Colors.white,
      title: const Text('Final save credits', textAlign: TextAlign.center),
      content: used == null
          ? const Text('Your credit balance is unavailable.')
          : Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Semantics(
                  label: '$percentage percent $label, $count of $limit credits',
                  child: ExcludeSemantics(
                    child: SizedBox.square(
                      dimension: 128,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          Positioned.fill(
                            child: TweenAnimationBuilder<double>(
                              tween: Tween(begin: 0, end: count / limit),
                              duration: MediaQuery.disableAnimationsOf(context)
                                  ? Duration.zero
                                  : const Duration(milliseconds: 350),
                              curve: Curves.easeOutCubic,
                              builder: (_, value, _) => CircularProgressIndicator(
                                value: value,
                                strokeWidth: 6,
                                strokeCap: StrokeCap.round,
                                backgroundColor: const Color(0xFFEDEDED),
                                color: TColors.vividRed,
                              ),
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.all(12),
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text('$percentage%', style: Theme.of(context).textTheme.headlineLarge),
                                  Text('$count of $limit $label'),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 22),
                SegmentedButton<bool>(
                  showSelectedIcon: false,
                  segments: const [
                    ButtonSegment(value: false, label: Text('Used')),
                    ButtonSegment(value: true, label: Text('Remaining')),
                  ],
                  selected: {_showRemaining},
                  onSelectionChanged: (value) => setState(() => _showRemaining = value.single),
                ),
                const SizedBox(height: 16),
                const Text('Each final save uses one credit. AI layers are free.',
                    textAlign: TextAlign.center),
              ],
            ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Done')),
      ],
    );
  }
}
