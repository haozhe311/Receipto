import 'package:flutter/material.dart';
import 'package:receipto/constants/theme.dart';

/// A selectable chip representing a payment method option.
///
/// Mirrors the visual style of [CategoryChip] but text-only (no icon/emoji).
class PaymentMethodChip extends StatelessWidget {
  final String method;
  final bool isSelected;
  final VoidCallback onTap;

  const PaymentMethodChip({
    super.key,
    required this.method,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          decoration: BoxDecoration(
            color: isSelected ? AppTheme.goldDark : AppTheme.surface,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isSelected ? AppTheme.gold : AppTheme.border,
              width: isSelected ? 1.5 : 1,
            ),
          ),
          child: Text(
            method,
            style: TextStyle(
              color: isSelected ? AppTheme.gold : AppTheme.textMuted,
              fontSize: 13,
              fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
            ),
          ),
        ),
      ),
    );
  }
}
