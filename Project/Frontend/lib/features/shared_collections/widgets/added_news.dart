import 'package:flutter/material.dart';
import '../../../common_theme/ui/app_colors.dart';
import '../model/added_news_model.dart';
import '../widgets/owner_pill.dart';

class AddedNewsCard extends StatelessWidget {
  final AddedNewsModel item;

  final String ownerHandle;

  final VoidCallback? onView;
  final LinearGradient ownerPillGradient;
  final bool? isMine;

  final VoidCallback? onDelete;
  final VoidCallback? onReport;
  final bool showActions;
  final bool isOwnedScreen;

  final bool isReportedByMe;


  const AddedNewsCard({
    super.key,
    required this.item,
    required this.ownerHandle,
    required this.ownerPillGradient,
    required this.isOwnedScreen,
    this.onView,
    this.isMine,
    this.onDelete,
    this.onReport,
    this.showActions = false,
    this.isReportedByMe = false,

  });

  bool get _isCreatorShared => item.sharedByCreator;
  bool get _isMine => isMine ?? item.isAddedByMe;

  @override
  Widget build(BuildContext context) {
    const radius = 18.0;

    final addedByName = ownerHandle.trim();

    final shouldShowOwnerPill =
        _isMine || addedByName.isNotEmpty || _isCreatorShared;

    final pillText = _isMine
        ? 'أضيفت بواسطتك'
        : (addedByName.isNotEmpty
            ? addedByName
            : (_isCreatorShared ? 'أضيفت بواسطة المالك' : ''));

    Widget buildActionButton() {
      if (_isMine) {
        return _DangerIconButton(
          icon: Icons.delete_rounded,
          tooltip: 'حذف الخبر',
          onTap: onDelete,
        );
      }

      if (isOwnedScreen) {
        return _DangerIconButton(
          icon: Icons.delete_rounded,
          tooltip: 'حذف الخبر',
          onTap: onDelete,
        );
      }

      return _DangerIconButton(
        icon: Icons.flag_rounded,
        tooltip: isReportedByMe ? 'تم الإبلاغ' : 'إبلاغ',
        onTap: isReportedByMe ? null : onReport,
      );
    }

String categoryToArabic(String? v) {
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

        
            child: Stack(
              children: [
                // =========================
                // Base card 
                // =========================
                Padding(
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
                              item.newsTitle,
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
                          if (showActions) ...[
                            const SizedBox(width: 10),
                            SizedBox(
                              width: 38,
                              height: 38,
                              child: Align(
                                alignment: Alignment.topLeft,
                                child: buildActionButton(),
                              ),
                            ),
                          ],
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
      label: item.newsSource,
      icon: Icons.public_rounded,
    ),
    _MetaChip(
      label: categoryToArabic(item.category),
      icon: Icons.interests_rounded,
    ),
    _DateChip(date: item.publishDate),
  ],
),
                      if (shouldShowOwnerPill) ...[
                        const SizedBox(height: 10),
                        Align(
                          alignment: Alignment.centerRight,
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 240),
                            child: OwnerPill.gradient(
                              owner: pillText,
                              gradient: ownerPillGradient,
                            ),
                          ),
                        ),
                      ] else if (_isCreatorShared) ...[
                        //
                      ],
                      const SizedBox(height: 14),
                      SizedBox(
                        width: double.infinity,
                        height: 44,
                        child: ElevatedButton(
                          onPressed: onView,
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

             if (isReportedByMe)
  Positioned.fill(
    child: AbsorbPointer(
      absorbing: true,
      child: Stack(
        fit: StackFit.expand,
        children: [
  
          Container(
            color: Colors.black.withOpacity(0.10),
          ),

          // Glass layer 
          Container(
            decoration: BoxDecoration(

              color: Colors.white.withOpacity(0.72),

              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.white.withOpacity(0.80),
                  Colors.white.withOpacity(0.66),
                ],
              ),
            ),
          ),

          // Center content
          Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.80),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.white.withOpacity(0.85)),
                  boxShadow: [
                    BoxShadow(
                      blurRadius: 18,
                      offset: const Offset(0, 10),
                      color: Colors.black.withOpacity(0.10),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
            
                    Container(
                      width: 34,
                      height: 34,
                      decoration: BoxDecoration(
                        color: AppColors.navy.withOpacity(0.10),
                        shape: BoxShape.circle,
                        border: Border.all(color: AppColors.navy.withOpacity(0.10)),
                      ),
                      child: const Icon(
                       Icons.verified_rounded,
                        color: AppColors.navy,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Flexible(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'شكرًا لبلاغك',
                            style: TextStyle(
                              fontFamily: 'NotoSansArabic',
                              fontWeight: FontWeight.w900,
                              fontSize: 14.5,
                              color: AppColors.navy,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'سيقوم المالك بمراجعة بلاغك قريبًا.',
                            style: TextStyle(
                              fontFamily: 'NotoSansArabic',
                              fontWeight: FontWeight.w800,
                              fontSize: 12.8,
                              color: AppColors.text.withOpacity(0.75),
                              height: 1.25,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    ),
  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _DangerIconButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback? onTap;

  const _DangerIconButton({
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final disabled = onTap == null;

    return Tooltip(
      message: tooltip,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: const Color(0xFFFFE9E9).withOpacity(disabled ? 0.55 : 1.0),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: const Color(0xFFFFC8C8).withOpacity(disabled ? 0.55 : 1.0),
            ),
          ),
          child: Center(
            child: Icon(
              icon,
              size: 20,
              color: const Color(0xFFD93A3A).withOpacity(disabled ? 0.55 : 1.0),
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
    // YYYY-MM-DD
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
          const Icon(Icons.calendar_month_rounded,
              size: 15, color: AppColors.navy),
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