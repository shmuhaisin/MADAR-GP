import 'package:flutter/material.dart';
import 'package:madar_app/features/news/models/article_model.dart';
import 'package:madar_app/common_theme/ui/app_colors.dart';

class NewsCard extends StatelessWidget {
  final ArticleModel article;
  final VoidCallback onTap;

  const NewsCard({
    super.key,
    required this.article,
    required this.onTap,
  });


  String _categoryToArabic(String? v) {
    switch ((v ?? '').trim()) {
      case 'Health':
        return 'الصحة';
      case 'Politics':
        return 'السياسة';
      case 'Entertainment':
        return 'الترفيه';
      case 'Technology':
        return 'التقنية';
      case 'Sports':
        return 'الرياضة';
      case 'Economy':
        return 'الاقتصاد';
      default:
        return (v == null || v.trim().isEmpty) ? 'الكل' : v.trim();
    }
  }

  @override
  Widget build(BuildContext context) {
    const radius = 18.0;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(radius),
          boxShadow: [
            BoxShadow(
              blurRadius: 16,
              offset: const Offset(0, 10),
              color: Colors.black.withOpacity(0.08),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(radius),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(radius),
              border: Border.all(color: const Color(0xFFE7E9F0)),
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Icon(
                          Icons.feed_rounded,
                          size: 20,
                          color: AppColors.navy.withOpacity(0.95),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          article.newsTitle,
                          textAlign: TextAlign.right,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontFamily: 'NotoSansArabic',
                            fontWeight: FontWeight.w900,
                            fontSize: 15.2,
                            color: AppColors.navy,
                            height: 1.28,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Wrap(
                    alignment: WrapAlignment.start,
                    runAlignment: WrapAlignment.start,
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                        _MetaChip(
                        label: article.newsSource,
                        icon: Icons.public_rounded,
                      ),
                      _MetaChip(
                        label: _categoryToArabic(article.category),
                        icon: Icons.interests_rounded,
                      ),
                    
                      _DateChip(date: article.publishDate),
                    ],
                  ),
                  const SizedBox(height: 14),
                  SizedBox(
                    width: double.infinity,
                    height: 44,
                    child: ElevatedButton(
                      onPressed: onTap,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.navy,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: const [
                          Text(
                            'عرض',
                            style: TextStyle(
                              fontFamily: 'NotoSansArabic',
                              fontWeight: FontWeight.w900,
                              fontSize: 13.6,
                            ),
                          ),
                          SizedBox(width: 10),
                          Icon(Icons.chevron_right_rounded, size: 22),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _MetaChip extends StatelessWidget {
  final String label;
  final IconData icon;

  const _MetaChip({
    required this.label,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final text = label.trim();
    if (text.isEmpty) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.navy.withOpacity(0.06),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppColors.navy.withOpacity(0.10)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 15,
            color: AppColors.navy,
          ),
          const SizedBox(width: 6),
          Text(
            text,
            style: const TextStyle(
              fontFamily: 'NotoSansArabic',
              fontWeight: FontWeight.w900,
              fontSize: 11.5,
              color: AppColors.navy,
            ),
          ),
        ],
      ),
    );
  }
}

class _DateChip extends StatelessWidget {
  final DateTime date;
  const _DateChip({required this.date});

  String _formatDate(DateTime d) {
    final y = d.year.toString().padLeft(4, '0');
    final m = d.month.toString().padLeft(2, '0');
    final day = d.day.toString().padLeft(2, '0');
    return '$y-$m-$day';
  }

  @override
  Widget build(BuildContext context) {
    if (date.millisecondsSinceEpoch == 0) return const SizedBox.shrink();

    final text = _formatDate(date);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.navy.withOpacity(0.04),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppColors.navy.withOpacity(0.08)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.calendar_month_rounded,
            size: 15,
            color: AppColors.navy,
          ),
          const SizedBox(width: 6),
          Text(
            text,
            style: const TextStyle(
              fontFamily: 'NotoSansArabic',
              fontWeight: FontWeight.w800,
              fontSize: 12,
              color: AppColors.navy,
            ),
          ),
        ],
      ),
    );
  }
}