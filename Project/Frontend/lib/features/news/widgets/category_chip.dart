import 'package:flutter/material.dart';
import 'package:madar_app/common_theme/ui/app_colors.dart';


class CategoryChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const CategoryChip({
    super.key,
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 38),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: isSelected ? AppColors.navy : AppColors.card,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: isSelected ? AppColors.navy : AppColors.divider),
          ),
          child: Center(
            child: Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: isSelected ? Colors.white : AppColors.navy,
                fontSize: 13,
                fontWeight: FontWeight.w800,
                fontFamily: 'NotoSansArabic',
              ),
            ),
          ),
        ),
      ),
    );
  }
}
