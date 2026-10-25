// ignore_for_file: camel_case_types

import 'package:flutter/material.dart';
import '../../../common_theme/ui/app_colors.dart';
import '../widgets/owner_pill.dart';



class ownedCard extends StatelessWidget {
  final String collectionId;
  final String title;
  final String description;
  final VoidCallback onView;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const ownedCard({
    super.key,
    required this.collectionId,
    required this.title,
    required this.description,
    required this.onView,
    required this.onEdit,
    required this.onDelete,
  });

  static const double cardHeight = 180;

  static const double _optionsReserve = 54;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: cardHeight,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          gradient: const LinearGradient(
            begin: Alignment.centerRight,
            end: Alignment.centerLeft,
            colors: [
              AppColors.accentBlue2,
              Color.fromARGB(255, 25, 41, 87),
            ],
          ),
          boxShadow: [
            BoxShadow(
              blurRadius: 18,
              offset: const Offset(0, 10),
              color: Colors.black.withOpacity(0.2),
            )
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: Stack(
            children: [
              Positioned(
                top: 0,
                left: 0,
                child: InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () async {
  await _showOwnedCardOptionsSheet(
    context: context,
    collectionTitle: title,
    onView: onView,
    onEdit: onEdit,
    onDelete: onDelete,
  );
},
                  child: Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.14),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.white.withOpacity(0.16)),
                    ),
                    child: const Center(
                      child: Icon(Icons.more_horiz, color: Colors.white, size: 20),
                    ),
                  ),
                ),
              ),

              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 2),

                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      InkWell(
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.14),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.white.withOpacity(0.16)),
                          ),
                          child: const Center(
                            child: Icon(Icons.collections_bookmark, color: Colors.white, size: 20),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),

                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.only(left: _optionsReserve),
                          child: Text(
                            title,
                            maxLines: 2,
                            softWrap: true,
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.right,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                              height: 1.25,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 8),

                  Padding(
                    padding: const EdgeInsetsDirectional.only(start: 5),
                    child: Text(
                      description,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.right,
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.92),
                        fontSize: 13.8,
                        height: 1.45,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),

                  const Spacer(),

                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton(
                          onPressed: onView,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.navy,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                              side: BorderSide(
                                color: Colors.white.withOpacity(0.55),
                                width: 0.66,
                              ),
                            ),
                            elevation: 10,
                            shadowColor: Colors.black.withOpacity(0.35),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            mainAxisSize: MainAxisSize.min,
                            children: const [
                              Text('عرض المجموعة'),
                              SizedBox(width: 10),
                              Icon(Icons.chevron_right, size: 20),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}



class JoinedCard extends StatelessWidget {
  final String title;
  final String description;
  final String ownerHandle;
  final VoidCallback onView;
  final Future<void> Function() onLeave;

  const JoinedCard({
    super.key,
    required this.title,
    required this.description,
    required this.ownerHandle,
    required this.onView,
    required this.onLeave,
  });

  static const double cardHeight = 230;

  static const double _iconBox = 36;
  static const double _gap = 8;

  // Same idea as ownedCard _optionsReserve.
  // This keeps long titles away from the top-left leave glass button.
  static const double _actionsReserve = 54;

  @override
  Widget build(BuildContext context) {
    const radius = 20.0;
    final hasOwner = ownerHandle.trim().isNotEmpty;

    return SizedBox(
      height: cardHeight,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(radius),
          boxShadow: [
            BoxShadow(
              blurRadius: 20,
              offset: const Offset(0, 10),
              color: Colors.black.withOpacity(0.10),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(radius),
          clipBehavior: Clip.antiAlias,
          child: Stack(
            children: [
              Positioned.fill(
                child: Container(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Color(0xFF5E80C2), // atmospheric blue
                        Color(0xFF4262AC), // royal blue
                        Color(0xFF2A4282), // navy presence
                        Color(0xFF553568), // rich amethyst
                        Color(0xFF8B3258), // wine
                        Color(0xFFB23E5C), // rosy burgundy
                      ],
                      stops: [0.0, 0.18, 0.40, 0.60, 0.80, 1.0],
                    ),
                  ),
                ),
              ),

              Positioned.fill(
                child: Container(
                  color: Colors.black.withOpacity(0.16),
                ),
              ),

              Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: Colors.white.withOpacity(0.16),
                      width: 1,
                    ),
                    borderRadius: BorderRadius.circular(radius),
                  ),
                ),
              ),

              // Top-left leave glass button.
              // Same glass style as owned card options button.
              Positioned(
                top: 16,
                left: 16,
                child: InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: onLeave,
                  child: Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.14),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: Colors.white.withOpacity(0.16),
                      ),
                    ),
                    child: const Center(
                      child: Icon(
                        Icons.logout_rounded,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                  ),
                ),
              ),

              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header row: collection icon + title
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Container(
                          width: _iconBox,
                          height: _iconBox,
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.14),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: Colors.white.withOpacity(0.16),
                            ),
                          ),
                          child: const Icon(
                            Icons.collections_bookmark,
                            color: Colors.white,
                            size: 20,
                          ),
                        ),

                        const SizedBox(width: _gap),

                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.only(
                              left: _actionsReserve,
                            ),
                            child: Text(
                              title,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              textAlign: TextAlign.right,
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                                color: Colors.white,
                                height: 1.20,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 8),

                    // Description
                    Padding(
                      padding: const EdgeInsetsDirectional.only(start: 3),
                      child: Text(
                        description,
                        maxLines: hasOwner ? 2 : 3,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.right,
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.92),
                          fontSize: 13.8,
                          height: 1.45,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),

                    if (hasOwner) ...[
                      const SizedBox(height: 10),
                      Align(
                        alignment: Alignment.centerRight,
                        child: OwnerPill.glass(owner: ownerHandle),
                      ),
                    ],

                    const Spacer(),

                    // Main action only
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: onView,
                            icon: const Icon(Icons.chevron_right, size: 20),
                            iconAlignment: IconAlignment.end,
                            label: const Text('عرض المجموعة'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.navy,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(
                                vertical: 12,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                                side: BorderSide(
                                  color: Colors.white.withOpacity(0.55),
                                  width: 0.66,
                                ),
                              ),
                              elevation: 5,
                              shadowColor: Colors.black.withOpacity(0.35),
                            ),
                          ),
                        ),
                      ],
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


Future<void> _showOwnedCardOptionsSheet({
  required BuildContext context,
  required String collectionTitle,
  required VoidCallback onView,
  required VoidCallback onEdit,
  required VoidCallback onDelete,
}) {
  final title = collectionTitle.trim();

  return showModalBottomSheet(
    context: context,
    backgroundColor: Colors.transparent,
    barrierColor: Colors.black.withOpacity(0.45),
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
    ),
    builder: (ctx) {
      return Directionality(
        textDirection: TextDirection.rtl,
        child: SafeArea(
          top: false,
          child: Container(
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 10),
                Container(
                  width: 44,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.divider,
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
                const SizedBox(height: 14),

                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    children: [
                      const Icon(Icons.collections_bookmark, color: AppColors.navy, size: 22),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          title.isEmpty ? 'المجموعة' : title,
                          textAlign: TextAlign.right,
                          style: const TextStyle(
                            fontFamily: 'NotoSansArabic',
                            fontWeight: FontWeight.w900,
                            fontSize: 16,
                            color: AppColors.navy,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 10),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16),
                  child: Divider(height: 1, color: AppColors.divider),
                ),

                _SheetTile(
                  icon: Icons.edit,
                  iconColor: AppColors.navy,
                  title: 'تحرير المجموعة',
                  onTap: () {
                    Navigator.pop(ctx);
                    onEdit();
                  },
                ),

                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16),
                  child: Divider(height: 1, color: AppColors.divider),
                ),

                _SheetTile(
                  icon: Icons.delete,
                  iconColor: AppColors.danger,
                  title: 'حذف المجموعة',
                  titleColor: AppColors.danger,
                  onTap: () {
                    Navigator.pop(ctx);
                    onDelete();
                  },
                ),

                const SizedBox(height: 10),
              ],
            ),
          ),
        ),
      );
    },
  );
}

class _SheetTile extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final Color? titleColor;
  final VoidCallback onTap;

  const _SheetTile({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.onTap,
    this.titleColor,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16),
      leading: Icon(icon, color: iconColor),
      title: Text(
        title,
        textAlign: TextAlign.right,
        style: TextStyle(
          fontFamily: 'NotoSansArabic',
          fontWeight: FontWeight.w800,
          fontSize: 15.5,
          color: titleColor ?? AppColors.navy,
        ),
      ),
      onTap: onTap,
    );
  }
}