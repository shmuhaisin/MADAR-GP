import 'package:flutter/material.dart';
import 'app_colors.dart';

class AppBottomNav extends StatelessWidget {
  final int currentIndex;
  final int notificationsCount;
  final ValueChanged<int> onTap;

  const AppBottomNav({
    super.key,
    required this.currentIndex,
    required this.notificationsCount,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.transparent,
        boxShadow: [
          BoxShadow(
            blurRadius: 22,
            offset: const Offset(0, -5),
            color: Colors.black.withOpacity(0.10),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(26),
          topRight: Radius.circular(26),
        ),
        child: Container(
          color: Colors.white,
          child: SafeArea(
            top: false,
            child: SizedBox(
              height: 76,
              child: Directionality(
                textDirection: TextDirection.rtl,
                child: Row(
                  children: [
                    _NavItem(
                      index: 0,
                      currentIndex: currentIndex,
                      icon: Icons.article_outlined,
                      selectedIcon: Icons.article_rounded,
                      label: 'الأخبار',
                      onTap: onTap,
                    ),
                    _NavItem(
                      index: 1,
                      currentIndex: currentIndex,
                      icon: Icons.explore_outlined,
                      selectedIcon: Icons.explore_rounded,
                      label: 'اكتشف',
                      onTap: onTap,
                    ),
                    _NavItem(
                      index: 2,
                      currentIndex: currentIndex,
                      icon: Icons.grid_view_outlined,
                      selectedIcon: Icons.grid_view_rounded,
                      label: 'المجموعات',
                      onTap: onTap,
                    ),
                    _NavItem(
                      index: 3,
                      currentIndex: currentIndex,
                      icon: Icons.notifications_none_rounded,
                      selectedIcon: Icons.notifications_rounded,
                      label: 'الإشعارات',
                      badgeCount: notificationsCount,
                      onTap: onTap,
                    ),
                    _NavItem(
                      index: 4,
                      currentIndex: currentIndex,
                      icon: Icons.person_outline_rounded,
                      selectedIcon: Icons.person_rounded,
                      label: 'حسابي',
                      onTap: onTap,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final int index;
  final int currentIndex;
  final IconData icon;
  final IconData selectedIcon;
  final String label;
  final int badgeCount;
  final ValueChanged<int> onTap;

  const _NavItem({
    required this.index,
    required this.currentIndex,
    required this.icon,
    required this.selectedIcon,
    required this.label,
    required this.onTap,
    this.badgeCount = 0,
  });

  @override
  Widget build(BuildContext context) {
    final isSelected = index == currentIndex;

    return Expanded(
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: () => onTap(index),
        child: Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 44,
                height: 32,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: isSelected
                      ? AppColors.navy.withOpacity(0.10)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Icon(
                      isSelected ? selectedIcon : icon,
                      size: 22,
                      color: isSelected
                          ? AppColors.navy
                          : AppColors.text.withOpacity(0.62),
                    ),
                    if (badgeCount > 0)
                      Positioned(
                        left: -9,
                        top: -7,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 5,
                            vertical: 1.5,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.danger,
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            badgeCount > 99 ? '99+' : '$badgeCount',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 9,
                              fontWeight: FontWeight.w900,
                              height: 1,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 4),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontFamily: 'NotoSansArabic',
                  fontSize: 10.5,
                  fontWeight: isSelected ? FontWeight.w900 : FontWeight.w700,
                  color: isSelected
                      ? AppColors.navy
                      : AppColors.text.withOpacity(0.62),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}