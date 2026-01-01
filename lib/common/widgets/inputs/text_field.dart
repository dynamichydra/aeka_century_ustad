import 'package:flutter/material.dart';
import '../../../../utils/constants/colors.dart';
import '../../../../utils/constants/sizes.dart';

class TTextField extends StatelessWidget {
  const TTextField({
    super.key,
    this.controller,
    this.labelText,
    this.prefixIcon,
    this.keyboardType,
    this.isCircularIcon = false,
    this.obscureText = false,
    this.validator,
    this.onChanged,
    this.fillColor,
    this.borderSide,
    this.contentPadding = const EdgeInsets.symmetric(vertical: TSizes.md, horizontal: TSizes.md),
    this.prefixPadding = const EdgeInsets.all(TSizes.sm),
    this.shadows,
  });

  final TextEditingController? controller;
  final String? labelText;
  final Widget? prefixIcon;
  final TextInputType? keyboardType;
  final bool isCircularIcon;
  final bool obscureText;
  final String? Function(String?)? validator;
  final void Function(String)? onChanged;
  final Color? fillColor;
  final BorderSide? borderSide;
  final EdgeInsetsGeometry contentPadding;
  final EdgeInsetsGeometry prefixPadding;
  final List<BoxShadow>? shadows;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: fillColor ?? const Color(0xFFE8E8E8), // Light grey matching image
        borderRadius: BorderRadius.circular(100), // Pill shape
        boxShadow: shadows ??
            [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.2), // Updated from withOpacity
                spreadRadius: 2,
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
            ],
      ),
      child: TextFormField(
        controller: controller,
        obscureText: obscureText,
        keyboardType: keyboardType,
        validator: validator,
        onChanged: onChanged,
        textAlign: TextAlign.start,
        style: const TextStyle(fontWeight: FontWeight.w500),
        decoration: InputDecoration(
          labelText: labelText,
          contentPadding: contentPadding,
          filled: true,
          fillColor: TColors.inputBackground, // Controlled by container
          prefixIcon: isCircularIcon && prefixIcon != null
              ? Container(
                  width: 45,
                  height: 45,
                  margin: const EdgeInsets.all(8),
                  padding: prefixPadding,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: TColors.white,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.2), // Updated from withOpacity
                        blurRadius: 15,
                        spreadRadius: 2,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: prefixIcon,
                )
              : prefixIcon,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(100),
            borderSide: borderSide ?? const BorderSide(color: Color(0xFFFFFFFF), width: 4),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(100),
            borderSide: borderSide ?? const BorderSide(color: Color(0xFFFFFFFF), width: 4),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(100),
            borderSide: borderSide ?? const BorderSide(color: TColors.white, width: 4),
          ),
          errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(100),
            borderSide: const BorderSide(color: TColors.error, width: 4),
          ),
          focusedErrorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(100),
            borderSide: const BorderSide(color: TColors.error, width: 4),
          ),
        ),
      ),
    );
  }
}
