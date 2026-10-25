import 'package:flutter/material.dart';
import 'package:madar_app/common_theme/ui/app_colors.dart';

class NewsPagination extends StatelessWidget {
  final int currentPage;
  final int totalPages;
  final ValueChanged<int> onPageSelected;

  final int maxSlots;

  const NewsPagination({
    super.key,
    required this.currentPage,
    required this.totalPages,
    required this.onPageSelected,
    this.maxSlots = 4,
  });

  @override
  Widget build(BuildContext context) {
    if (totalPages <= 1) return const SizedBox.shrink();

    final tokens = _paginationTokens(
      count: totalPages,
      current: currentPage - 1, 
      maxSlots: maxSlots,
    );

    final isFirstPage = currentPage == 1;
    final isLastPage = currentPage == totalPages;

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        IconButton(
          tooltip: 'Previous',
          onPressed: isFirstPage ? null : () => onPageSelected(currentPage - 1),
          icon: const Icon(Icons.chevron_left),
        ),
        Wrap(
          spacing: 8,
          children: tokens.map((t) {
            if (t == -1) return const _EllipsisPill();

            final pageNumber = t + 1;
            final selected = pageNumber == currentPage;

            return InkWell(
              borderRadius: BorderRadius.circular(999),
              onTap: () => onPageSelected(pageNumber),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                decoration: BoxDecoration(
                  color: selected
                      ? AppColors.navy2
                      : AppColors.navy.withOpacity(0.10),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(
                    color: Colors.white.withOpacity(selected ? 0.8 : 0.25),
                  ),
                ),
                child: Text(
                  '$pageNumber',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 11,
                    color: selected ? Colors.white : AppColors.text,
                  ),
                ),
              ),
            );
          }).toList(),
        ),
        IconButton(
          tooltip: 'Next',
          onPressed: isLastPage ? null : () => onPageSelected(currentPage + 1),
          icon: const Icon(Icons.chevron_right),
        ),
      ],
    );
  }

  List<int> _paginationTokens({
    required int count,
    required int current,
    required int maxSlots,
  }) {
    if (count <= maxSlots) return List.generate(count, (i) => i);

    final last = count - 1;
    final window = maxSlots - 2;

    int start = current - (window ~/ 2);
    int end = start + window - 1;

    if (start < 1) {
      start = 1;
      end = start + window - 1;
    }

    if (end > last - 1) {
      end = last - 1;
      start = end - window + 1;
    }

    final res = <int>[0];

    if (start > 1) {
      res.add(start == 2 ? 1 : -1);
    }

    for (int i = start; i <= end; i++) {
      res.add(i);
    }

    if (end < last - 1) {
      res.add(end == last - 2 ? last - 1 : -1);
    }

    res.add(last);
    return res;
  }
}

class _EllipsisPill extends StatelessWidget {
  const _EllipsisPill();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.navy.withOpacity(0.08),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withOpacity(0.18)),
      ),
      child: const Text(
        '…',
        style: TextStyle(
          fontWeight: FontWeight.w900,
          fontSize: 12,
          color: AppColors.text,
        ),
      ),
    );
  }
}