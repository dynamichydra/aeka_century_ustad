import 'package:century_ai/core/constants/colors.dart';
import 'package:century_ai/core/constants/final_save_credits.dart';
import 'package:flutter/material.dart';

class CreditUsageButton extends StatelessWidget {
  const CreditUsageButton({super.key, required this.used, required this.size});

  final int? used;
  final double size;

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
      style: IconButton.styleFrom(
        backgroundColor: Colors.white,
        shape: const CircleBorder(),
        fixedSize: Size.square(size),
        minimumSize: Size.zero,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
      onPressed: () => showCreditUsageDialog(context, used),
      icon: ExcludeSemantics(
        child: SizedBox.square(
          dimension: size,
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
                    strokeWidth: 1,
                    strokeCap: StrokeCap.round,
                    backgroundColor: Colors.black12,
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
      barrierColor: const Color(0x4D000000),
      builder: (_) => _CreditUsageDialog(used: used),
    );

class _CreditUsageDialog extends StatelessWidget {
  const _CreditUsageDialog({required this.used});

  final int? used;

  @override
  Widget build(BuildContext context) {
    const limit = FinalSaveCredits.limit;
    final usedCoins = used?.clamp(0, limit);
    final fraction = (usedCoins ?? 0) / limit;
    final percentage = (fraction * 100).round();
    final showWarning = fraction > 0.70;
    const bodyStyle = TextStyle(
      fontSize: 12,
      fontWeight: FontWeight.w600,
      color: TColors.pureBlack,
    );

    return Dialog(
      backgroundColor: TColors.pureWhite,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      insetPadding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
      constraints: const BoxConstraints(maxWidth: 420),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 24),
        child: SizedBox(
          width: double.infinity,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Coin Usage',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 21,
                  fontWeight: FontWeight.w700,
                  color: TColors.pureBlack,
                ),
              ),
              if (usedCoins == null) ...[
                const SizedBox(height: 24),
                const Text(
                  'Your coin balance is unavailable.',
                  textAlign: TextAlign.center,
                  style: bodyStyle,
                ),
              ] else ...[
                const SizedBox(height: 12),
                SizedBox(
                  height: 24,
                  child: showWarning
                      ? const Icon(
                          Icons.warning_rounded,
                          color: TColors.vividRed,
                          size: 24,
                          semanticLabel: 'Coin usage is above 70 percent',
                        )
                      : null,
                ),
                const SizedBox(height: 8),
                const FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    '1 coin is used each time you click Apply',
                    maxLines: 1,
                    style: bodyStyle,
                  ),
                ),
                const SizedBox(height: 22),
                Semantics(
                  label: '$percentage percent of coins used',
                  excludeSemantics: true,
                  child: SizedBox.square(
                    dimension: 124,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        Positioned.fill(
                          child: RotatedBox(
                            quarterTurns: 2,
                            child: TweenAnimationBuilder<double>(
                              tween: Tween(begin: 0, end: fraction),
                              duration: MediaQuery.disableAnimationsOf(context)
                                  ? Duration.zero
                                  : const Duration(milliseconds: 350),
                              curve: Curves.easeOutCubic,
                              builder: (context, value, child) =>
                                  CircularProgressIndicator(
                                    value: value,
                                    strokeWidth: 3.5,
                                    strokeCap: StrokeCap.butt,
                                    backgroundColor: TColors.lightGray,
                                    color: TColors.vividRed,
                                  ),
                            ),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.all(12),
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(
                              '$percentage%',
                              style: bodyStyle.copyWith(
                                fontSize: 30,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    'Total: $limit coins | Used: $usedCoins coins | '
                    'Remaining: ${limit - usedCoins} coins',
                    maxLines: 1,
                    style: bodyStyle,
                  ),
                ),
              ],
              const SizedBox(height: 18),
              ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(84, 44),
                  backgroundColor: TColors.vividRed,
                  foregroundColor: TColors.pureWhite,
                  shape: const StadiumBorder(),
                  elevation: 3,
                ),
                child: const Text('OK'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
